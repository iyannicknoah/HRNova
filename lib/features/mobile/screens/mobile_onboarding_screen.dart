import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/ui_providers.dart';
import '../../../core/theme/app_colors.dart';

class MobileOnboardingScreen extends ConsumerStatefulWidget {
  const MobileOnboardingScreen({super.key});

  @override
  ConsumerState<MobileOnboardingScreen> createState() =>
      _MobileOnboardingScreenState();
}

class _MobileOnboardingScreenState
    extends ConsumerState<MobileOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mobile_onboarding_seen', true);
    ref.read(mobileOnboardingSeenProvider.notifier).state = true;
    if (mounted) context.go('/login');
  }

  static const _bg = Color(0xFF070E1C);
  static const _card = Color(0xFF0D1628);
  static const _blue = AppColors.primaryBlue;
  static const _green = Color(0xFF1DB87A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // ── Logo ─────────────────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_blue, Color(0xFF6B5FE8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text('HRNova',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        )),
                  ]),

                  const SizedBox(height: 44),

                  // ── Heading ──────────────────────────────────────────────
                  const Text('Welcome\nto HRNova.',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                        letterSpacing: -1,
                      )),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to get started.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withAlpha(130),
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Guard Mode card ──────────────────────────────────────
                  _ActionCard(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Guard Mode',
                    subtitle: 'Sign in with your company HR\ncredentials to scan attendance',
                    gradientColors: const [Color(0xFF4A9EFF), Color(0xFF6B5FE8)],
                    onTap: _proceed,
                  ),

                  const SizedBox(height: 16),

                  // ── Divider with OR ──────────────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(color: Colors.white.withAlpha(20), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('or',
                          style: TextStyle(
                              color: Colors.white.withAlpha(60),
                              fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withAlpha(20), thickness: 1)),
                  ]),

                  const SizedBox(height: 16),

                  // ── Employee card ────────────────────────────────────────
                  _ActionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Employee Portal',
                    subtitle: 'View leave, payslips and\nyour attendance history',
                    gradientColors: const [Color(0xFF1DB87A), Color(0xFF00897B)],
                    onTap: _proceed,
                  ),

                  const Spacer(),

                  // ── Footer ───────────────────────────────────────────────
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Text(
                        'Your role is set by your HR Administrator',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(60),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1628),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(14)),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 25),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      )),
                  const SizedBox(height: 4),
                  Text(widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(110),
                        height: 1.4,
                      )),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
