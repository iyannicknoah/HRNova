import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/application_model.dart';
import '../models/job_posting_model.dart';

// ── Firestore refs ────────────────────────────────────────────────────────────
CollectionReference<Map<String, dynamic>> _jobsRef(String companyId) =>
    FirebaseService.db.collection('companies').doc(companyId).collection('jobs');

CollectionReference<Map<String, dynamic>> _appsRef(String companyId) =>
    FirebaseService.db.collection('companies').doc(companyId).collection('applications');

// ── Job postings stream ───────────────────────────────────────────────────────
final jobPostingsStreamProvider = StreamProvider.autoDispose
    .family<List<JobPostingModel>, String>((ref, companyId) {
  return _jobsRef(companyId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => JobPostingModel.fromMap(d.id, d.data())).toList());
});

// ── Applications stream for a job ─────────────────────────────────────────────
typedef AppKey = ({String companyId, String jobId});

final jobApplicationsStreamProvider = StreamProvider.autoDispose
    .family<List<ApplicationModel>, AppKey>((ref, key) {
  return _appsRef(key.companyId)
      .where('jobId', isEqualTo: key.jobId)
      .snapshots()
      .map((s) {
        final list = s.docs
            .map((d) => ApplicationModel.fromMap(d.id, d.data()))
            .toList();
        list.sort((a, b) => (b.aiScore ?? -1).compareTo(a.aiScore ?? -1));
        return list;
      });
});

// ── Single application stream ─────────────────────────────────────────────────
typedef DetailKey = ({String companyId, String jobId, String appId});

final applicationDetailStreamProvider = StreamProvider.autoDispose
    .family<ApplicationModel?, DetailKey>((ref, key) {
  return _appsRef(key.companyId).doc(key.appId).snapshots().map(
        (s) => s.exists ? ApplicationModel.fromMap(s.id, s.data()!) : null,
      );
});

// ── Pending rejections count for a job ───────────────────────────────────────
final pendingRejectionsProvider = StreamProvider.autoDispose
    .family<List<ApplicationModel>, AppKey>((ref, key) {
  return _appsRef(key.companyId)
      .where('jobId', isEqualTo: key.jobId)
      .where('status', isEqualTo: 'declined')
      .where('rejectionConfirmedByHR', isEqualTo: true)
      .snapshots()
      .map((s) {
        return s.docs
            .map((d) => ApplicationModel.fromMap(d.id, d.data()))
            .where((a) => a.rejectionSentAt == null)
            .toList();
      });
});

// ── Stats ─────────────────────────────────────────────────────────────────────
class RecruitmentStats {
  final int openPositions;
  final int totalApplications;
  final int shortlisted;
  final int hired;
  const RecruitmentStats({
    this.openPositions = 0,
    this.totalApplications = 0,
    this.shortlisted = 0,
    this.hired = 0,
  });
}

final recruitmentStatsProvider = FutureProvider.autoDispose
    .family<RecruitmentStats, String>((ref, companyId) async {
  try {
    final res = await ApiService()
        .get('/api/recruitment/stats', params: {'companyId': companyId});
    final d = res.data as Map<String, dynamic>;
    return RecruitmentStats(
      openPositions: d['openPositions'] as int? ?? 0,
      totalApplications: d['totalApplications'] as int? ?? 0,
      shortlisted: d['shortlisted'] as int? ?? 0,
      hired: d['hired'] as int? ?? 0,
    );
  } catch (_) {
    return const RecruitmentStats();
  }
});

// ── Action state & notifier ───────────────────────────────────────────────────
class RecruitmentState {
  final bool loading;
  final String? error;
  final String? successMessage;
  final String? createdJobId;
  final String? publicUrl;
  const RecruitmentState({
    this.loading = false,
    this.error,
    this.successMessage,
    this.createdJobId,
    this.publicUrl,
  });
  RecruitmentState copyWith({
    bool? loading,
    String? error,
    String? successMessage,
    String? createdJobId,
    String? publicUrl,
  }) =>
      RecruitmentState(
        loading: loading ?? this.loading,
        error: error,
        successMessage: successMessage ?? this.successMessage,
        createdJobId: createdJobId ?? this.createdJobId,
        publicUrl: publicUrl ?? this.publicUrl,
      );
  RecruitmentState get idle => const RecruitmentState();
}

class RecruitmentNotifier extends StateNotifier<RecruitmentState> {
  final Ref _ref;
  RecruitmentNotifier(this._ref) : super(const RecruitmentState());

  String get _cid => _ref.read(currentCompanyIdProvider) ?? '';

  Future<bool> createJob(Map<String, dynamic> data) async {
    state = const RecruitmentState(loading: true);
    try {
      final res = await ApiService()
          .post('/api/recruitment/jobs', data: {'companyId': _cid, ...data});
      state = RecruitmentState(
        successMessage: 'Job posted successfully',
        createdJobId: res.data['jobId'] as String?,
        publicUrl: res.data['publicUrl'] as String?,
      );
      return true;
    } catch (e) {
      state = RecruitmentState(error: e.toString());
      return false;
    }
  }

  Future<bool> updateJob(String jobId, Map<String, dynamic> data) async {
    state = const RecruitmentState(loading: true);
    try {
      await ApiService().put('/api/recruitment/jobs/$jobId',
          data: {'companyId': _cid, ...data});
      state = const RecruitmentState(successMessage: 'Job updated');
      return true;
    } catch (e) {
      state = RecruitmentState(error: e.toString());
      return false;
    }
  }

  Future<bool> shortlistApplication({
    required String appId,
    required String jobId,
    bool sendInvite = false,
    String? interviewDate,
    String? interviewTime,
    String? interviewLocation,
  }) async {
    state = const RecruitmentState(loading: true);
    try {
      await ApiService().put('/api/recruitment/applications/$appId/shortlist', data: {
        'companyId': _cid,
        'jobId': jobId,
        'sendInvite': sendInvite,
        if (interviewDate != null) 'interviewDate': interviewDate,
        if (interviewTime != null) 'interviewTime': interviewTime,
        if (interviewLocation != null) 'interviewLocation': interviewLocation,
      });
      state = RecruitmentState(
        successMessage: sendInvite ? 'Shortlisted & invitation sent' : 'Applicant shortlisted',
      );
      return true;
    } catch (e) {
      state = RecruitmentState(error: e.toString());
      return false;
    }
  }

  Future<bool> declineApplication(String appId) async {
    state = const RecruitmentState(loading: true);
    try {
      await ApiService().put('/api/recruitment/applications/$appId/decline',
          data: {'companyId': _cid});
      state = const RecruitmentState(successMessage: 'Marked as declined');
      return true;
    } catch (e) {
      state = RecruitmentState(error: e.toString());
      return false;
    }
  }

  Future<int> sendRejections(String jobId, String companyName) async {
    state = const RecruitmentState(loading: true);
    try {
      final res = await ApiService().post(
          '/api/recruitment/jobs/$jobId/send-rejections',
          data: {'companyId': _cid, 'companyName': companyName});
      final sent = res.data['sent'] as int? ?? 0;
      state = RecruitmentState(successMessage: 'Sent $sent rejection emails');
      return sent;
    } catch (e) {
      state = RecruitmentState(error: e.toString());
      return 0;
    }
  }

  void clear() => state = const RecruitmentState();
}

final recruitmentNotifierProvider =
    StateNotifierProvider<RecruitmentNotifier, RecruitmentState>(
        (ref) => RecruitmentNotifier(ref));
