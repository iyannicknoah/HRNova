import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';

// ── Firestore stream of recent reports by type ────────────────────────────────
final reportsStreamProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, type) {
  final companyId = ref.watch(currentCompanyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseService.reportsRef(companyId)
      .where('type', isEqualTo: type)
      .orderBy('generatedAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map((d) {
            final data = d.data();
            return {...data, 'id': d.id};
          }).toList());
});

// ── State for report generation ───────────────────────────────────────────────
class ReportState {
  final bool loading;
  final String? report;
  final String? error;
  const ReportState({this.loading = false, this.report, this.error});
  ReportState copyWith({bool? loading, String? report, String? error}) =>
      ReportState(loading: loading ?? this.loading, report: report ?? this.report, error: error ?? this.error);
}

class ReportNotifier extends StateNotifier<ReportState> {
  final String companyId;
  ReportNotifier(this.companyId) : super(const ReportState());

  Future<void> generateDaily({String? date, String? branchId}) async {
    state = const ReportState(loading: true);
    try {
      final res = await ApiService().post('/api/reports/daily', data: {
        'companyId': companyId,
        if (date != null) 'date': date,
        if (branchId != null) 'branchId': branchId,
      });
      state = ReportState(report: res.data['report'] as String?);
    } catch (e) {
      state = ReportState(error: e.toString());
    }
  }

  Future<void> generateWeekly({String? startDate, String? branchId}) async {
    state = const ReportState(loading: true);
    try {
      final res = await ApiService().post('/api/reports/weekly', data: {
        'companyId': companyId,
        if (startDate != null) 'startDate': startDate,
        if (branchId != null) 'branchId': branchId,
      });
      state = ReportState(report: res.data['report'] as String?);
    } catch (e) {
      state = ReportState(error: e.toString());
    }
  }

  Future<void> generateMonthly({String? month, String? branchId}) async {
    state = const ReportState(loading: true);
    try {
      final res = await ApiService().post('/api/reports/monthly', data: {
        'companyId': companyId,
        if (month != null) 'month': month,
        if (branchId != null) 'branchId': branchId,
      });
      state = ReportState(report: res.data['report'] as String?);
    } catch (e) {
      state = ReportState(error: e.toString());
    }
  }

  Future<void> generateGroupDaily({String? date}) async {
    state = const ReportState(loading: true);
    try {
      final res = await ApiService().post('/api/reports/group-daily', data: {
        'companyId': companyId,
        if (date != null) 'date': date,
      });
      state = ReportState(report: res.data['report'] as String?);
    } catch (e) {
      state = ReportState(error: e.toString());
    }
  }

  void clear() => state = const ReportState();
}

// Keyed by report type ('daily', 'weekly', 'monthly', 'group') so each tab
// has independent loading/result state.
final reportNotifierProvider =
    StateNotifierProvider.autoDispose.family<ReportNotifier, ReportState, String>((ref, reportType) {
  final companyId = ref.watch(currentCompanyIdProvider) ?? '';
  return ReportNotifier(companyId);
});

// ── Nova AI chat state ────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime at;
  const ChatMessage({required this.text, required this.isUser, required this.at});
}

class NovaAiState {
  final List<ChatMessage> messages;
  final bool loading;
  final String? error;
  const NovaAiState({this.messages = const [], this.loading = false, this.error});
  NovaAiState copyWith({List<ChatMessage>? messages, bool? loading, String? error}) =>
      NovaAiState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        error: error ?? this.error,
      );
}

class NovaAiNotifier extends StateNotifier<NovaAiState> {
  final String companyId;
  final String? branchId;
  NovaAiNotifier(this.companyId, this.branchId) : super(const NovaAiState());

  Future<void> ask(String question) async {
    if (question.trim().isEmpty) return;
    final userMsg = ChatMessage(text: question, isUser: true, at: DateTime.now());
    state = state.copyWith(messages: [...state.messages, userMsg], loading: true, error: null);
    try {
      final res = await ApiService().post('/api/reports/ask', data: {
        'companyId': companyId,
        'question': question,
        if (branchId != null) 'branchId': branchId,
      });
      final answer = res.data['answer'] as String? ?? 'No answer returned.';
      final novaMsg = ChatMessage(text: answer, isUser: false, at: DateTime.now());
      state = state.copyWith(messages: [...state.messages, novaMsg], loading: false);
    } catch (e) {
      final errMsg = ChatMessage(
        text: 'Sorry, I could not answer that right now. Please try again.',
        isUser: false, at: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, errMsg], loading: false, error: e.toString());
    }
  }

  void clear() => state = const NovaAiState();
}

final novaAiProvider =
    StateNotifierProvider.autoDispose<NovaAiNotifier, NovaAiState>((ref) {
  final companyId = ref.watch(currentCompanyIdProvider) ?? '';
  final branchId  = ref.watch(currentBranchIdProvider);
  return NovaAiNotifier(companyId, branchId);
});
