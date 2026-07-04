import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _glow(double size, Color color, int alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withAlpha(alpha), Colors.transparent],
          ),
        ),
      );

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
          _emailController.text,
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final signInState = ref.watch(authNotifierProvider);

    // Show splash loading while Firebase auth initialises
    if (authState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.darkNavy,
        body: LoadingWidget(message: 'Starting HRNova…'),
      );
    }

    final isLoading = signInState.isLoading;
    final errorMsg = signInState.hasError ? signInState.error.toString() : null;

    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(
        children: [
          // Top-right: main blue glow
          Positioned(
            top: -180,
            right: -150,
            child: _glow(620, AppColors.primaryBlue, 22),
          ),
          // Bottom-left: teal glow
          Positioned(
            bottom: -130,
            left: -100,
            child: _glow(460, AppColors.accentTeal, 18),
          ),
          // Top-left: soft indigo accent
          Positioned(
            top: 60,
            left: -80,
            child: _glow(340, const Color(0xFF667EEA), 14),
          ),
          // Bottom-right: faint secondary blue
          Positioned(
            bottom: 40,
            right: -60,
            child: _glow(260, AppColors.primaryBlue, 10),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Login card
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 40,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: AppColors.primaryBlue.withAlpha(20),
                              blurRadius: 60,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(36),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Logo
                                Center(
                                  child: RichText(
                                    text: const TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'HR',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.darkNavy,
                                            letterSpacing: -1.0,
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'Nova',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primaryBlue,
                                            letterSpacing: -1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Center(
                                  child: Text(
                                    'Your HR Team, Supercharged',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Divider
                                Container(
                                  height: 0.5,
                                  color: AppColors.cardBorder,
                                ),
                                const SizedBox(height: 28),

                                // Email
                                HRNovaTextField(
                                  label: 'Email address',
                                  hint: 'you@company.rw',
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Please enter your email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password
                                HRNovaTextField(
                                  label: 'Password',
                                  hint: '••••••••',
                                  controller: _passwordController,
                                  obscureText: !_showPassword,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _signIn(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),

                                // Error message
                                if (errorMsg != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorRed.withAlpha(12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.errorRed.withAlpha(40)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded,
                                            color: AppColors.errorRed, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            errorMsg,
                                            style: const TextStyle(
                                              color: AppColors.errorRed,
                                              fontSize: 15,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Sign In button
                                HRNovaButton(
                                  label: 'Sign In',
                                  onPressed: isLoading ? null : _signIn,
                                  isLoading: isLoading,
                                  isFullWidth: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
