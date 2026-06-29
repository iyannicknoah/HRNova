import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:hrnova/core/theme/app_colors.dart';
import 'package:hrnova/features/auth/providers/auth_provider.dart';
import 'package:hrnova/features/settings/providers/settings_provider.dart';

// ─── States ────────────────────────────────────────────────────────────────
enum CheckinState {
  scanning,
  error,
  countdown,
  uploading,
  successOnTime,
  successLate,
  successCheckout,
  alreadyDone,
}

// ─── Screen ─────────────────────────────────────────────────────────────────
class TabletCheckinScreen extends ConsumerStatefulWidget {
  const TabletCheckinScreen({super.key});

  @override
  ConsumerState<TabletCheckinScreen> createState() =>
      _TabletCheckinScreenState();
}

class _TabletCheckinScreenState extends ConsumerState<TabletCheckinScreen> {
  // Clock
  late Timer _clockTimer;
  String _currentTime = '';

  // States
  CheckinState _state = CheckinState.scanning;
  String _employeeName = '';
  String _employeeFirstName = '';
  String _errorMessage = 'Employee not found';
  String _errorSubMessage = 'Please contact HR Admin';
  int _countdownNumber = 3;
  String _checkoutFirstName = '';
  String _checkoutHours = '0';
  String _checkoutMinutes = '0';
  int _lateMinutes = 0;
  String _checkinTime = '';

  // QR Scanner
  final MobileScannerController _scannerController = MobileScannerController();
  bool _scanPaused = false;

  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  // Firestore
  FirebaseFirestore get _firestore =>
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateClock();
    });
    _loadCameras();
  }

  void _updateClock() {
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _loadCameras() async {
    if (kIsWeb) return; // Camera package not supported on web
    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = [];
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _scannerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── QR Scan Handler ─────────────────────────────────────────────────────
  Future<void> _onQRDetected(BarcodeCapture capture) async {
    if (_scanPaused || _state != CheckinState.scanning) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final qrValue = barcodes.first.rawValue;
    if (qrValue == null || qrValue.isEmpty) return;

    _scanPaused = true;
    await _scannerController.stop();

    final companyId = ref.read(companyIdProvider);
    if (companyId == null) {
      _showError('Configuration error', 'Company ID not found');
      return;
    }

    try {
      // Step 1: Find employee by QR code
      final empQuery = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('employees')
          .where('qrCode', isEqualTo: qrValue)
          .limit(1)
          .get();

      if (empQuery.docs.isEmpty) {
        _showError('Employee not found', 'Please contact HR Admin');
        return;
      }

      final empDoc = empQuery.docs.first;
      final empData = empDoc.data();
      final employeeId = empDoc.id;
      final firstName = empData['firstName'] as String? ?? '';
      final lastName = empData['lastName'] as String? ?? '';
      final department = empData['department'] as String? ?? '';
      final fullName = '$firstName $lastName';

      // Step 2: Check today's attendance
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendanceDocId = '${today}_$employeeId';
      final attendanceRef = _firestore
          .collection('companies')
          .doc(companyId)
          .collection('attendance')
          .doc(attendanceDocId);

      final attendanceDoc = await attendanceRef.get();

      if (!attendanceDoc.exists) {
        // CHECK-IN FLOW
        await _handleCheckin(
          companyId: companyId,
          employeeId: employeeId,
          firstName: firstName,
          lastName: lastName,
          fullName: fullName,
          department: department,
          attendanceRef: attendanceRef,
        );
      } else {
        final data = attendanceDoc.data()!;
        final checkoutTime = data['checkOutTime'];
        if (checkoutTime != null) {
          // Already completed
          setState(() {
            _employeeFirstName = firstName;
            _state = CheckinState.alreadyDone;
          });
          Timer(const Duration(seconds: 3), _returnToScanning);
        } else {
          // CHECK-OUT FLOW
          await _handleCheckout(
            companyId: companyId,
            firstName: firstName,
            attendanceRef: attendanceRef,
            existingData: data,
          );
        }
      }
    } catch (e) {
      debugPrint('[TabletCheckin] Error: $e');
      _showError('System error', 'Please try again');
    }
  }

  // ── Check-In Flow ───────────────────────────────────────────────────────
  Future<void> _handleCheckin({
    required String companyId,
    required String employeeId,
    required String firstName,
    required String lastName,
    required String fullName,
    required String department,
    required DocumentReference attendanceRef,
  }) async {
    setState(() {
      _employeeName = fullName;
      _employeeFirstName = firstName;
      _countdownNumber = 3;
      _state = CheckinState.countdown;
    });

    // Init camera
    if (_cameras.isNotEmpty) {
      _cameraController =
          CameraController(_cameras.first, ResolutionPreset.medium);
      await _cameraController!.initialize();
    }

    // Countdown 3, 2, 1
    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownNumber = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    // Capture photo
    Uint8List? compressedBytes;
    String? photoUrl;
    String? photoKey;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        final rawBytes = await xFile.readAsBytes();
        compressedBytes = _compressImage(rawBytes);
        debugPrint('[TabletCheckin] Photo size after compression: ${compressedBytes.length} bytes');

        setState(() => _state = CheckinState.uploading);

        final uploadResult = await _uploadPhoto(
          compressedBytes,
          companyId,
          employeeId,
          'checkin',
        );
        photoUrl = uploadResult?['url'];
        photoKey = uploadResult?['key'];
      } catch (e) {
        debugPrint('[TabletCheckin] Camera/upload error: $e');
        setState(() => _state = CheckinState.uploading);
      }
    } else {
      setState(() => _state = CheckinState.uploading);
    }

    // Calculate status
    final settings = ref.read(settingsProvider).valueOrNull;
    final startTimeParts = (settings?.workStartTime ?? '08:00').split(':');
    final startHour = int.tryParse(startTimeParts[0]) ?? 8;
    final startMinute = startTimeParts.length > 1 ? (int.tryParse(startTimeParts[1]) ?? 0) : 0;
    final gracePeriod = settings?.gracePeriodMinutes ?? 10;

    final now = DateTime.now();
    final deadline = DateTime(now.year, now.month, now.day, startHour, startMinute)
        .add(Duration(minutes: gracePeriod));

    final String status;
    final int lateMin;
    if (now.isBefore(deadline) || now.isAtSameMomentAs(deadline)) {
      status = 'on_time';
      lateMin = 0;
    } else {
      status = 'late';
      lateMin = now.difference(deadline).inMinutes;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final monthStr = DateFormat('yyyy-MM').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    // Save to Firestore
    await attendanceRef.set({
      'employeeId': employeeId,
      'employeeName': '$firstName $lastName',
      'department': department,
      'date': dateStr,
      'month': monthStr,
      'checkInTime': Timestamp.now(),
      'checkInPhotoUrl': photoUrl,
      'checkInPhotoKey': photoKey,
      'status': status,
      'lateMinutes': lateMin,
      'isApprovedLeave': false,
      'isManualEntry': false,
      'checkOutTime': null,
      'checkOutPhotoUrl': null,
      'checkOutPhotoKey': null,
      'totalHoursWorked': null,
    });

    // Cleanup camera
    await _cameraController?.dispose();
    _cameraController = null;

    setState(() {
      _checkinTime = timeStr;
      _lateMinutes = lateMin;
      _state = status == 'on_time'
          ? CheckinState.successOnTime
          : CheckinState.successLate;
    });

    Timer(const Duration(seconds: 4), _returnToScanning);
  }

  // ── Check-Out Flow ──────────────────────────────────────────────────────
  Future<void> _handleCheckout({
    required String companyId,
    required String firstName,
    required DocumentReference attendanceRef,
    required Map<String, dynamic> existingData,
  }) async {
    final employeeId = existingData['employeeId'] as String? ?? '';

    setState(() {
      _employeeName = 'Checking out — $firstName';
      _employeeFirstName = firstName;
      _countdownNumber = 3;
      _state = CheckinState.countdown;
    });

    if (_cameras.isNotEmpty) {
      _cameraController =
          CameraController(_cameras.first, ResolutionPreset.medium);
      await _cameraController!.initialize();
    }

    for (int i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownNumber = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    Uint8List? compressedBytes;
    String? photoUrl;
    String? photoKey;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        final rawBytes = await xFile.readAsBytes();
        compressedBytes = _compressImage(rawBytes);

        setState(() => _state = CheckinState.uploading);

        final uploadResult = await _uploadPhoto(
          compressedBytes,
          companyId,
          employeeId,
          'checkout',
        );
        photoUrl = uploadResult?['url'];
        photoKey = uploadResult?['key'];
      } catch (e) {
        debugPrint('[TabletCheckin] Checkout camera/upload error: $e');
        setState(() => _state = CheckinState.uploading);
      }
    } else {
      setState(() => _state = CheckinState.uploading);
    }

    final now = DateTime.now();
    final checkInTimestamp = existingData['checkInTime'] as Timestamp?;
    double totalHours = 0;
    if (checkInTimestamp != null) {
      final diff = now.difference(checkInTimestamp.toDate());
      totalHours = diff.inMinutes / 60.0;
    }

    // Calculate early leave
    final settings = ref.read(settingsProvider).valueOrNull;
    final endTimeParts = (settings?.workEndTime ?? '17:00').split(':');
    final endHour = int.tryParse(endTimeParts[0]) ?? 17;
    final endMinute = endTimeParts.length > 1 ? (int.tryParse(endTimeParts[1]) ?? 0) : 0;
    final workEnd = DateTime(now.year, now.month, now.day, endHour, endMinute);
    final earlyLeaveMinutes = now.isBefore(workEnd) ? workEnd.difference(now).inMinutes : 0;

    await attendanceRef.update({
      'checkOutTime': Timestamp.now(),
      'checkOutPhotoUrl': photoUrl,
      'checkOutPhotoKey': photoKey,
      'totalHoursWorked': double.parse(totalHours.toStringAsFixed(2)),
      'earlyLeaveMinutes': earlyLeaveMinutes,
    });

    await _cameraController?.dispose();
    _cameraController = null;

    final totalH = totalHours.floor();
    final totalM = ((totalHours - totalH) * 60).round();

    setState(() {
      _checkoutFirstName = firstName;
      _checkoutHours = totalH.toString();
      _checkoutMinutes = totalM.toString();
      _state = CheckinState.successCheckout;
    });

    Timer(const Duration(seconds: 4), _returnToScanning);
  }

  // ── Image Compression ───────────────────────────────────────────────────
  Uint8List _compressImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    int quality = 85;
    List<int> compressed = img.encodeJpg(decoded, quality: quality);

    while (compressed.length > 102400 && quality > 10) {
      quality -= 5;
      compressed = img.encodeJpg(decoded, quality: quality);
    }

    return Uint8List.fromList(compressed);
  }

  // ── Photo Upload ────────────────────────────────────────────────────────
  Future<Map<String, String>?> _uploadPhoto(
    Uint8List bytes,
    String companyId,
    String employeeId,
    String photoType,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:3000/api/storage/upload-photo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['companyId'] = companyId;
      request.fields['employeeId'] = employeeId;
      request.fields['photoType'] = photoType;
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: '${employeeId}_$photoType.jpg',
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        // Parse JSON manually
        final body = response.body;
        final urlMatch = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body);
        final keyMatch = RegExp(r'"key"\s*:\s*"([^"]+)"').firstMatch(body);
        return {
          'url': urlMatch?.group(1) ?? '',
          'key': keyMatch?.group(1) ?? '',
        };
      }
    } catch (e) {
      debugPrint('[TabletCheckin] Upload request error: $e');
    }
    return null;
  }

  // ── State Helpers ───────────────────────────────────────────────────────
  void _showError(String message, String subMessage) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _errorSubMessage = subMessage;
      _state = CheckinState.error;
    });
    Timer(const Duration(seconds: 3), _returnToScanning);
  }

  void _returnToScanning() {
    if (!mounted) return;
    setState(() => _state = CheckinState.scanning);
    _scanPaused = false;
    _scannerController.start();
  }

  // ──────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final companyNameAsync = ref.watch(companyNameProvider);
    final companyName = companyNameAsync.maybeWhen(
      data: (n) => n,
      orElse: () => 'HRNova',
    );

    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(
        children: [
          // ── Base Layer: QR Scanner ──
          _buildScannerLayer(),
          // ── Top Bar ──
          _buildTopBar(companyName),
          // ── Bottom Bar ──
          _buildBottomBar(),
          // ── Overlay states ──
          if (_state == CheckinState.error) _buildErrorOverlay(),
          if (_state == CheckinState.countdown) _buildCountdownOverlay(),
          if (_state == CheckinState.uploading) _buildUploadingOverlay(),
          if (_state == CheckinState.successOnTime) _buildSuccessOnTimeOverlay(),
          if (_state == CheckinState.successLate) _buildSuccessLateOverlay(),
          if (_state == CheckinState.successCheckout) _buildCheckoutOverlay(),
          if (_state == CheckinState.alreadyDone) _buildAlreadyDoneOverlay(),
        ],
      ),
    );
  }

  // ── Scanner Layer ──────────────────────────────────────────────────────
  Widget _buildScannerLayer() {
    return Positioned.fill(
      child: MobileScanner(
        controller: _scannerController,
        onDetect: _onQRDetected,
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────
  Widget _buildTopBar(String companyName) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 70,
        color: AppColors.darkNavy.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // Logo
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'HR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  TextSpan(
                    text: 'Nova',
                    style: TextStyle(
                      color: AppColors.lightGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            // Company name
            Expanded(
              child: Text(
                companyName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Clock
            Text(
              _currentTime,
              style: const TextStyle(
                color: AppColors.lightGreen,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 50,
        color: Colors.black.withOpacity(0.5),
        alignment: Alignment.center,
        child: Text(
          'Scan your ID card to check in or check out',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // ── Error Overlay ──────────────────────────────────────────────────────
  Widget _buildErrorOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.red.withOpacity(0.92),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.close, color: Colors.white, size: 96),
            const SizedBox(height: 24),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorSubMessage,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ── Countdown Overlay ──────────────────────────────────────────────────
  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Camera preview or dark bg
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            Positioned.fill(child: Container(color: Colors.black87)),
          // Name overlay at top
          Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Text(
              _employeeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
          // Countdown number
          Center(
            child: Text(
              '$_countdownNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 120,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 20, color: Colors.black54)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Uploading Overlay ──────────────────────────────────────────────────
  Widget _buildUploadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.lightGreen,
              strokeWidth: 4,
            ),
            SizedBox(height: 24),
            Text(
              'Recording attendance...',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success On Time ────────────────────────────────────────────────────
  Widget _buildSuccessOnTimeOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF059669), // Emerald green
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 96),
            const SizedBox(height: 24),
            Text(
              'Welcome, $_employeeFirstName!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Checked in at $_checkinTime',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Success Late ───────────────────────────────────────────────────────
  Widget _buildSuccessLateOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFFD97706), // Amber
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, color: Colors.white, size: 96),
            const SizedBox(height: 24),
            Text(
              '$_employeeFirstName — Late',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_lateMinutes minutes late · Checked in at $_checkinTime',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Check-Out Success ──────────────────────────────────────────────────
  Widget _buildCheckoutOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.infoBlue,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room, color: Colors.white, size: 96),
            const SizedBox(height: 24),
            Text(
              'Goodbye, $_checkoutFirstName!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You worked ${_checkoutHours}h ${_checkoutMinutes}m today',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── Already Done Overlay ────────────────────────────────────────────────
  Widget _buildAlreadyDoneOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.infoBlue.withOpacity(0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all, color: Colors.white, size: 96),
            const SizedBox(height: 24),
            const Text(
              'Already completed today',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_employeeFirstName checked in and out',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
