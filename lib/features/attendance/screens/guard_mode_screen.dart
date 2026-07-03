import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../employees/providers/employees_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/attendance_provider.dart';

// ── State machine ─────────────────────────────────────────────────────────────
enum _ScanState {
  scanning,
  loading,
  notFound,
  checkInSuccess,
  lateArrival,
  checkOutSuccess,
  alreadyDone,
}

// ── Scan result payload ───────────────────────────────────────────────────────
class _ScanResult {
  const _ScanResult({
    required this.name,
    required this.jobTitle,
    required this.department,
    this.photoUrl,
    this.lateMinutes = 0,
    this.hoursWorked = 0.0,
    this.checkInTimeStr = '',
  });
  final String name, jobTitle, department, checkInTimeStr;
  final String? photoUrl;
  final int lateMinutes;
  final double hoursWorked;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class GuardModeScreen extends ConsumerStatefulWidget {
  const GuardModeScreen({super.key});

  @override
  ConsumerState<GuardModeScreen> createState() => _GuardModeScreenState();
}

class _GuardModeScreenState extends ConsumerState<GuardModeScreen> {
  _ScanState _state = _ScanState.scanning;
  _ScanResult? _result;
  Timer? _clock;
  Timer? _resetTimer;
  String _timeStr = '';
  int _checkedInCount = 0;
  bool _processing = false;

  final MobileScannerController _scannerController =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  @override
  void initState() {
    super.initState();
    _tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final n = DateTime.now();
    final s =
        '${_p(n.hour)}:${_p(n.minute)}:${_p(n.second)}';
    if (mounted) setState(() => _timeStr = s);
  }

  static String _p(int v) => v.toString().padLeft(2, '0');

  @override
  void dispose() {
    _clock?.cancel();
    _resetTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  // ── QR detected ────────────────────────────────────────────────────────────
  Future<void> _onQRDetected(String qrCode) async {
    if (_processing || _state != _ScanState.scanning) return;
    _processing = true;
    await _scannerController.stop();

    setState(() => _state = _ScanState.loading);

    try {
      // Lookup employee by QR code
      final employee = await ref.read(employeeByQRProvider(qrCode).future);

      if (employee == null || !employee.isActive) {
        setState(() => _state = _ScanState.notFound);
        _scheduleReset();
        return;
      }

      // Check today's attendance record
      final todayRecord = await ref
          .read(attendanceNotifierProvider.notifier)
          .getTodayRecord(employee.id);

      if (todayRecord != null &&
          todayRecord.checkInTime != null &&
          todayRecord.checkOutTime != null) {
        // Already fully done for today
        final ciStr = _p(todayRecord.checkInTime!.hour) +
            ':' +
            _p(todayRecord.checkInTime!.minute);
        setState(() {
          _result = _ScanResult(
            name: employee.fullName,
            jobTitle: employee.jobTitle,
            department: employee.department,
            photoUrl: employee.profilePhotoUrl,
            checkInTimeStr: ciStr,
          );
          _state = _ScanState.alreadyDone;
          _checkedInCount++;
        });
        _scheduleReset();
        return;
      }

      if (todayRecord != null && todayRecord.checkInTime != null) {
        // Has check-in, needs check-out
        await ref
            .read(attendanceNotifierProvider.notifier)
            .checkOut(employeeId: employee.id);

        final ciStr = _p(todayRecord.checkInTime!.hour) +
            ':' +
            _p(todayRecord.checkInTime!.minute);
        final now = DateTime.now();
        final worked = now.difference(todayRecord.checkInTime!).inMinutes / 60;

        setState(() {
          _result = _ScanResult(
            name: employee.fullName,
            jobTitle: employee.jobTitle,
            department: employee.department,
            photoUrl: employee.profilePhotoUrl,
            hoursWorked: worked,
            checkInTimeStr: ciStr,
          );
          _state = _ScanState.checkOutSuccess;
        });
        _scheduleReset();
        return;
      }

      // No record → check in
      final record = await ref
          .read(attendanceNotifierProvider.notifier)
          .checkIn(
            employeeId: employee.id,
            branchId: employee.branchId,
            isManual: false,
          );

      final isLate = record.isLate;
      final now = DateTime.now();
      final checkInStr =
          '${_p(now.hour)}:${_p(now.minute)}';

      setState(() {
        _result = _ScanResult(
          name: employee.fullName,
          jobTitle: employee.jobTitle,
          department: employee.department,
          photoUrl: employee.profilePhotoUrl,
          lateMinutes: record.lateMinutes,
          checkInTimeStr: checkInStr,
        );
        _state = isLate
            ? _ScanState.lateArrival
            : _ScanState.checkInSuccess;
        _checkedInCount++;
      });
      _scheduleReset();
    } catch (e) {
      setState(() => _state = _ScanState.notFound);
      _scheduleReset();
    }
  }

  void _scheduleReset() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _state = _ScanState.scanning;
          _result = null;
          _processing = false;
        });
        _scannerController.start();
      }
    });
  }

  Widget _stateOverlay() {
    return switch (_state) {
      _ScanState.scanning        => const SizedBox.shrink(key: ValueKey('scan')),
      _ScanState.loading         => const _LoadingOverlay(key: ValueKey('load')),
      _ScanState.notFound        => const _NotFoundOverlay(key: ValueKey('nf')),
      _ScanState.checkInSuccess  => _result == null
          ? const SizedBox.shrink()
          : _CheckInOverlay(result: _result!, isLate: false, key: const ValueKey('in')),
      _ScanState.lateArrival     => _result == null
          ? const SizedBox.shrink()
          : _CheckInOverlay(result: _result!, isLate: true, key: const ValueKey('late')),
      _ScanState.checkOutSuccess => _result == null
          ? const SizedBox.shrink()
          : _CheckOutOverlay(result: _result!, key: const ValueKey('out')),
      _ScanState.alreadyDone     => _result == null
          ? const SizedBox.shrink()
          : _AlreadyDoneOverlay(result: _result!, key: const ValueKey('done')),
    };
  }

  @override
  Widget build(BuildContext context) {
    final companyName = ref.watch(companySettingsProvider).value?.companyName ?? 'HRNova';

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Column(children: [
        _TopBar(timeStr: _timeStr, checkedIn: _checkedInCount, companyName: companyName),
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            // Live camera / QR scanner
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue != null) {
                  _onQRDetected(barcode!.rawValue!);
                }
              },
            ),
            // QR frame overlay
            const _ScanOverlay(),
            // State result overlays
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _stateOverlay(),
            ),
          ]),
        ),
        _BottomHint(active: _state == _ScanState.scanning),
      ]),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.timeStr,
      required this.checkedIn,
      required this.companyName});
  final String timeStr, companyName;
  final int checkedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
      decoration: const BoxDecoration(color: Color(0xFF0D1628)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.shield_rounded,
              color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 8),
          const Text('Guard Mode',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Expanded(
            child: Text(companyName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          const Spacer(),
          Text(timeStr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.successGreen, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Today: $checkedIn checked in',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ── QR scan frame overlay ─────────────────────────────────────────────────────
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FramePainter());
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameW = 260.0;
    const frameH = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - frameW / 2;
    final top = cy - frameH / 2;
    final rect = Rect.fromLTWH(left, top, frameW, frameH);

    // Dark vignette with transparent hole
    final vigPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)));
    canvas.drawPath(
        vigPath, Paint()..color = Colors.black.withAlpha(140));

    // Blue corner brackets
    const c = Color(0xFF4A9EFF);
    const len = 26.0;
    const thick = 3.5;
    final p = Paint()
      ..color = c
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = [
      [Offset(left, top + len), Offset(left, top), Offset(left + len, top)],
      [Offset(left + frameW - len, top), Offset(left + frameW, top), Offset(left + frameW, top + len)],
      [Offset(left + frameW, top + frameH - len), Offset(left + frameW, top + frameH), Offset(left + frameW - len, top + frameH)],
      [Offset(left + len, top + frameH), Offset(left, top + frameH), Offset(left, top + frameH - len)],
    ];
    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, p);
    }

    // Hint text
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Position employee QR code inside the frame',
        style: TextStyle(
            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 280);
    tp.paint(canvas,
        Offset(cx - tp.width / 2, top + frameH + 20));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Bottom hint bar ───────────────────────────────────────────────────────────
class _BottomHint extends StatelessWidget {
  const _BottomHint({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xFF060D18),
      child: AnimatedOpacity(
        opacity: active ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 300),
        child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.primaryBlue, size: 18),
              SizedBox(width: 8),
              Text('Scan QR code to check in / check out',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ]),
      ),
    );
  }
}

// ── Loading overlay ───────────────────────────────────────────────────────────
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(210),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// ── Not found overlay ─────────────────────────────────────────────────────────
class _NotFoundOverlay extends StatelessWidget {
  const _NotFoundOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5534B),
      child: const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person_off_rounded,
                size: 40, color: Colors.white),
          ),
          SizedBox(height: 20),
          Text('Employee Not Found',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text('Please contact HR Admin',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ]),
      ),
    );
  }
}

// ── Check-in overlay (on time + late) ────────────────────────────────────────
class _CheckInOverlay extends StatelessWidget {
  const _CheckInOverlay(
      {super.key, required this.result, required this.isLate});
  final _ScanResult result;
  final bool isLate;

  @override
  Widget build(BuildContext context) {
    String pad(int v) => v.toString().padLeft(2, '0');
    final bg = isLate ? const Color(0xFFF5A623) : const Color(0xFF1DB87A);
    final now = DateTime.now();
    final t = '${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)}';

    return Container(
      color: bg,
      child: Stack(children: [
        Positioned.fill(
          child: Center(
            child: Icon(Icons.check_circle_outline_rounded,
                size: 400,
                color: Colors.white.withAlpha(18)),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _GuardAvatar(
                name: result.name, photoUrl: result.photoUrl, size: 120),
            const SizedBox(height: 22),
            Text(result.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${result.jobTitle}  ·  ${result.department}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(100)),
              child: const Text('CHECK IN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
            ),
            const SizedBox(height: 16),
            if (isLate) ...[
              Text('LATE — ${result.lateMinutes} minutes',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(t,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 16)),
            ] else ...[
              Text(t,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(100)),
                child: const Text('ON TIME',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Check-out overlay ─────────────────────────────────────────────────────────
class _CheckOutOverlay extends StatelessWidget {
  const _CheckOutOverlay({super.key, required this.result});
  final _ScanResult result;

  @override
  Widget build(BuildContext context) {
    String pad(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final t = '${pad(now.hour)}:${pad(now.minute)}';
    final h = result.hoursWorked.floor();
    final m = ((result.hoursWorked - h) * 60).round();

    return Container(
      color: const Color(0xFF4A9EFF),
      child: Stack(children: [
        Positioned.fill(
          child: Center(
            child: Icon(Icons.logout_rounded,
                size: 400,
                color: Colors.white.withAlpha(18)),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _GuardAvatar(
                name: result.name, photoUrl: result.photoUrl, size: 120),
            const SizedBox(height: 22),
            Text(result.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${result.jobTitle}  ·  ${result.department}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(100)),
              child: const Text('CHECK OUT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
            ),
            const SizedBox(height: 16),
            Text(t,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Worked: ${h}h ${m}m today',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 20)),
          ]),
        ),
      ]),
    );
  }
}

// ── Already done overlay ──────────────────────────────────────────────────────
class _AlreadyDoneOverlay extends StatelessWidget {
  const _AlreadyDoneOverlay({super.key, required this.result});
  final _ScanResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C2C),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _GuardAvatar(
              name: result.name, photoUrl: result.photoUrl, size: 100),
          const SizedBox(height: 20),
          Text(result.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Already completed today',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Checked in at ${result.checkInTimeStr}',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ── Guard avatar ──────────────────────────────────────────────────────────────
class _GuardAvatar extends StatelessWidget {
  const _GuardAvatar(
      {required this.name, this.photoUrl, required this.size});
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withAlpha(80), width: 3),
        ),
        child: ClipOval(
          child: Image.network(photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials()),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final colors = AppColors.gradientForName(name);
    final parts = name.split(' ');
    final ini = parts
        .take(2)
        .map((p) => p.isNotEmpty ? p[0] : '')
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        border:
            Border.all(color: Colors.white.withAlpha(80), width: 3),
      ),
      alignment: Alignment.center,
      child: Text(ini,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.33,
              fontWeight: FontWeight.w700)),
    );
  }
}
