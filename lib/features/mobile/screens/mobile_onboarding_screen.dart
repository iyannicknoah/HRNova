import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _bg = Color(0xFF070E1C);
const _card = Color(0xFF0D1628);
const _border = Color(0xFF1A2E4A);

class MobileOnboardingScreen extends StatelessWidget {
  const MobileOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildBrand(),
              const SizedBox(height: 56),
              _buildRoleHeader(),
              const SizedBox(height: 24),
              _RoleCard(
                icon: Icons.badge_rounded,
                title: 'Employee',
                subtitle: 'View payslips, request leave\nand track your attendance',
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A9EFF), Color(0xFF2E7DE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => context.go('/login'),
              ),
              const Spacer(flex: 3),
              const Text(
                'v1.0.0 · HRNova Rwanda',
                style: TextStyle(color: Color(0xFF3A4A6A), fontSize: 14),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A9EFF), Color(0xFF2E7DE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A9EFF).withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.people_rounded, color: Colors.white, size: 42),
        ),
        const SizedBox(height: 18),
        const Text(
          'HRNova',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Smart HR for Modern Rwanda',
          style: TextStyle(color: Color(0xFF6B7A99), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildRoleHeader() {
    return Column(
      children: const [
        Text(
          'How are you using HRNova?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6),
        Text(
          'Select your role to continue',
          style: TextStyle(color: Color(0xFF6B7A99), fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7A99),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF3A4A6A),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
