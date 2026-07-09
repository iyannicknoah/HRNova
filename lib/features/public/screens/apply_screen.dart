import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/platform/file_upload_any_helper.dart';
import '../../../core/platform/file_upload_helper.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';

class ApplyScreen extends StatefulWidget {
  const ApplyScreen({
    super.key,
    required this.companySlug,
    required this.jobSlug,
  });

  final String companySlug;
  final String jobSlug;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  // ── Job data ──────────────────────────────────────────────────────────────
  Map<String, dynamic>? _job;
  String? _companyId;
  String? _companyName;
  bool _loadingJob = true;
  String? _loadError;

  // ── Form ──────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _experience = TextEditingController();
  final _coverLetter = TextEditingController();

  // ── CV upload ────────────────────────────────────────────────────────────
  String? _cvFileName;
  Uint8List? _cvBytes;
  String? _cvUrl;
  String? _cvKey;
  bool _uploadingCv = false;
  String? _cvError;

  // ── Certifications upload ─────────────────────────────────────────────────
  String? _certFileName;
  Uint8List? _certBytes;
  String? _certUrl;
  String? _certKey;
  bool _uploadingCert = false;
  String? _certError;

  // ── Submission ────────────────────────────────────────────────────────────
  bool _submitting = false;
  String? _submitError;

  Future<void> _pickCert() async {
    setState(() { _certError = null; });
    try {
      final result = await pickAnyFile();
      if (result == null) return;
      setState(() {
        _certBytes = result.bytes;
        _certFileName = result.name;
        _uploadingCert = true;
        _certUrl = null;
        _certKey = null;
      });

      final formData = FormData.fromMap({
        'cert': MultipartFile.fromBytes(result.bytes, filename: result.name),
        'companyId': _companyId ?? '',
        'jobId': _job?['id'] as String? ?? '',
        'applicantName': _name.text.trim().isEmpty ? 'applicant' : _name.text.trim(),
      });
      final res = await ApiService().postMultipart('/api/storage/upload-cert', formData);
      if (!mounted) return;
      setState(() {
        _certUrl = res.data['url'] as String?;
        _certKey = res.data['key'] as String?;
        _uploadingCert = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _certError = e.toString().replaceFirst('Exception: ', '');
        _uploadingCert = false;
        _certBytes = null;
        _certFileName = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose();
    _experience.dispose(); _coverLetter.dispose();
    super.dispose();
  }

  Future<void> _loadJob() async {
    try {
      final res = await ApiService().get(
          '/api/recruitment/public/job/${widget.companySlug}/${widget.jobSlug}');
      if (!mounted) return;
      setState(() {
        _job = res.data['job'] as Map<String, dynamic>?;
        _companyId = res.data['companyId'] as String?;
        _companyName = res.data['companyName'] as String?;
        _loadingJob = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingJob = false;
      });
    }
  }

  Future<void> _pickCv() async {
    setState(() { _cvError = null; });

    late final Uint8List bytes;
    late final String fileName;
    try {
      final result = await pickPdfFile();
      if (result == null) return;
      bytes = result.bytes;
      fileName = result.name;
    } catch (e) {
      setState(() => _cvError = e.toString().replaceFirst('Exception: ', ''));
      return;
    }

    setState(() {
      _cvBytes = bytes;
      _cvFileName = fileName;
      _uploadingCv = true;
      _cvUrl = null;
      _cvKey = null;
    });

    // Upload immediately so we have the URL/key before final submit
    try {
      final formData = FormData.fromMap({
        'cv': MultipartFile.fromBytes(bytes,
            filename: fileName,
            contentType: DioMediaType('application', 'pdf')),
        'companyId': _companyId ?? '',
        'jobId': _job?['id'] as String? ?? '',
        'applicantName': _name.text.trim().isEmpty ? 'applicant' : _name.text.trim(),
      });

      final res = await ApiService().postMultipart('/api/storage/upload-cv', formData);
      if (!mounted) return;
      setState(() {
        _cvUrl = res.data['url'] as String?;
        _cvKey = res.data['key'] as String?;
        _uploadingCv = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cvError = 'Upload failed: ${e.toString()}';
        _uploadingCv = false;
        _cvBytes = null;
        _cvFileName = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _submitting = true; _submitError = null; });

    try {
      await ApiService().post('/api/recruitment/public/apply', data: {
        'companyId': _companyId,
        'jobId': _job?['id'],
        'jobTitle': _job?['title'],
        'applicantName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'yearsExperience': int.tryParse(_experience.text.trim()) ?? 0,
        'coverLetter': _coverLetter.text.trim(),
        'cvUrl': _cvUrl,
        'cvKey': _cvKey,
        'certUrl': _certUrl,
        'certKey': _certKey,
        'companyName': _companyName,
      });
      if (!mounted) return;
      context.go('/apply-success');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, Color(0xFF2979E0)]),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('HRNova',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.cardBorder),
        ),
      ),
      body: _loadingJob
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _LoadError(error: _loadError!)
              : SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Job info sidebar
                            SizedBox(
                              width: 220,
                              child: _JobSidebar(
                                job: _job,
                                companyName: _companyName,
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Application form
                            Expanded(child: _ApplicationForm(
                              formKey: _formKey,
                              name: _name,
                              email: _email,
                              phone: _phone,
                              experience: _experience,
                              coverLetter: _coverLetter,
                              cvFileName: _cvFileName,
                              uploadingCv: _uploadingCv,
                              cvUrl: _cvUrl,
                              cvError: _cvError,
                              onPickCv: _pickCv,
                              certFileName: _certFileName,
                              uploadingCert: _uploadingCert,
                              certUrl: _certUrl,
                              certError: _certError,
                              onPickCert: _pickCert,
                              submitting: _submitting,
                              submitError: _submitError,
                              onSubmit: _submit,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}

// ── Job sidebar ───────────────────────────────────────────────────────────────
class _JobSidebar extends StatelessWidget {
  final Map<String, dynamic>? job;
  final String? companyName;
  const _JobSidebar({required this.job, required this.companyName});

  @override
  Widget build(BuildContext context) {
    if (job == null) return const SizedBox();
    final skills = (job!['requiredSkills'] as List<dynamic>? ?? []).cast<String>();
    final minExp = job!['minExperience'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (companyName != null)
            Text(companyName!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(job!['title'] as String? ?? '',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.business_rounded,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(job!['department'] as String? ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary))),
            ],
          ),
          if (minExp > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.work_history_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('$minExp+ years experience',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
          const Divider(height: 24),
          if ((job!['description'] as String?)?.isNotEmpty == true) ...[
            const Text('About the Role',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(job!['description'] as String,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.6),
                maxLines: 8,
                overflow: TextOverflow.ellipsis),
            const Divider(height: 24),
          ],
          if (skills.isNotEmpty) ...[
            const Text('Required Skills',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: skills.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryBlue.withAlpha(40)),
                    ),
                    child: Text(s,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primaryBlue)),
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Application form ──────────────────────────────────────────────────────────
class _ApplicationForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController name, email, phone, experience, coverLetter;
  final String? cvFileName;
  final bool uploadingCv;
  final String? cvUrl;
  final String? cvError;
  final VoidCallback onPickCv;
  final String? certFileName;
  final bool uploadingCert;
  final String? certUrl;
  final String? certError;
  final VoidCallback onPickCert;
  final bool submitting;
  final String? submitError;
  final VoidCallback onSubmit;

  const _ApplicationForm({
    required this.formKey,
    required this.name,
    required this.email,
    required this.phone,
    required this.experience,
    required this.coverLetter,
    required this.cvFileName,
    required this.uploadingCv,
    required this.cvUrl,
    required this.cvError,
    required this.onPickCv,
    required this.certFileName,
    required this.uploadingCert,
    required this.certUrl,
    required this.certError,
    required this.onPickCert,
    required this.submitting,
    required this.submitError,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Application',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('All fields marked * are required.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            // Name
            _Label('Full Name *'),
            TextFormField(
              controller: name,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _dec(context, 'Your full name'),
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            // Email
            _Label('Email Address *'),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _dec(context, 'your@email.com'),
              validator: (v) {
                if (v?.trim().isEmpty == true) return 'Email is required';
                if (!RegExp(r'^.+@.+\..+$').hasMatch(v!.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Phone
            _Label('Phone Number *'),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _dec(context, '+250 7XX XXX XXX'),
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Phone number is required' : null,
            ),
            const SizedBox(height: 14),

            // Experience
            _Label('Years of Experience *'),
            TextFormField(
              controller: experience,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _dec(context, 'e.g. 3'),
              validator: (v) =>
                  v?.trim().isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Cover letter
            _Label('Cover Letter (Optional)'),
            TextFormField(
              controller: coverLetter,
              maxLines: 5,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: _dec(context,
                  'Tell us why you are the right person for this role...'),
            ),
            const SizedBox(height: 14),

            // CV Upload
            _Label('CV / Resume (PDF, max 5 MB)'),
            _CvUploadBox(
              fileName: cvFileName,
              uploading: uploadingCv,
              fileUrl: cvUrl,
              error: cvError,
              onPick: onPickCv,
              hint: 'Click to upload PDF',
            ),
            const SizedBox(height: 14),

            // Certifications Upload (optional)
            _Label('Certifications (PDF or Image, optional)'),
            _CvUploadBox(
              fileName: certFileName,
              uploading: uploadingCert,
              fileUrl: certUrl,
              error: certError,
              onPick: onPickCert,
              hint: 'Click to upload PDF or image',
            ),
            const SizedBox(height: 24),

            // Error
            if (submitError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.errorRed.withAlpha(40)),
                ),
                child: Text(submitError!,
                    style: const TextStyle(
                        color: AppColors.errorRed, fontSize: 13)),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (submitting || uploadingCv) ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Application',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(BuildContext context, String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.cardBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.errorRed)),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
    );
  }
}

// ── CV upload box ─────────────────────────────────────────────────────────────
class _CvUploadBox extends StatelessWidget {
  final String? fileName;
  final bool uploading;
  final String? fileUrl;
  final String? error;
  final VoidCallback onPick;
  final String hint;
  const _CvUploadBox({
    required this.fileName,
    required this.uploading,
    required this.fileUrl,
    required this.error,
    required this.onPick,
    this.hint = 'Click to upload PDF',
  });

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('Uploading...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (fileUrl != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.successGreen.withAlpha(50)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.successGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(fileName ?? 'File uploaded',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.successGreen),
                  overflow: TextOverflow.ellipsis),
            ),
            TextButton(
              onPressed: onPick,
              child: const Text('Change',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.primaryBlue)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: error != null
                      ? AppColors.errorRed
                      : AppColors.cardBorder,
                  style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.upload_file_rounded,
                    color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 10),
                Text(hint,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!,
              style: const TextStyle(fontSize: 12, color: AppColors.errorRed)),
        ],
      ],
    );
  }
}

// ── Load error ────────────────────────────────────────────────────────────────
class _LoadError extends StatelessWidget {
  final String error;
  const _LoadError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.errorRed),
          const SizedBox(height: 16),
          const Text('Job not found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('This job may have been closed or the link has expired.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
