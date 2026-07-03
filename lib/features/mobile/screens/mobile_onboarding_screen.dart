import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

class MobileOnboardingScreen extends StatefulWidget {
  const MobileOnboardingScreen({super.key});

  @override
  State<MobileOnboardingScreen> createState() => _MobileOnboardingScreenState();
}

class _MobileOnboardingScreenState extends State<MobileOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
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

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mobile_onboarding_seen', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 52),
                  // ── Logo ──────────────────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.accentTeal],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text('HRNova',
                        style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.5,
                        )),
                  ]),
                  const SizedBox(height: 52),
                  // ── Heading ───────────────────────────────────────────────
                  const Text('Welcome.', style: TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1.1, letterSpacing: -1,
                  )),
                  const SizedBox(height: 10),
                  Text('Tell us who you are\nto get started.',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w400,
                        color: Colors.white.withAlpha(140), height: 1.5,
                      )),
                  const SizedBox(height: 44),
                  // ── Role cards ────────────────────────────────────────────
                  _RoleCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Employee',
                    subtitle: 'Request leave, view attendance\nand check your payslips',
                    gradient: const [Color(0xFF4A9EFF), Color(0xFF6B5FE8)],
                    onTap: _continue,
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.shield_outlined,
                    title: 'Guard',
                    subtitle: 'Scan employee QR codes\nto record attendance',
                    gradient: const [Color(0xFF1DB87A), Color(0xFF00897B)],
                    onTap: _continue,
                  ),
                  const Spacer(),
                  // ── Footer ────────────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _continue,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: 'HR Admin? ',
                              style: TextStyle(
                                fontSize: 14, color: Colors.white.withAlpha(100),
                              ),
                            ),
                            const TextSpan(
                              text: 'Sign in here →',
                              style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ]),
                        ),
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

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1628),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(12)),
          ),
          child: Row(children: [
            // Icon in gradient circle
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(widget.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 18),
            // Text
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.3,
                  )),
              const SizedBox(height: 5),
              Text(widget.subtitle,
                  style: TextStyle(
                    fontSize: 13, color: Colors.white.withAlpha(120),
                    height: 1.5,
                  )),
            ])),
            const SizedBox(width: 12),
            // Arrow
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.white.withAlpha(120)),
            ),
          ]),
        ),
      ),
    );
  }
}
