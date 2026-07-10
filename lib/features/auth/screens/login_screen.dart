import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/hrnova_button.dart';
import '../../../shared/widgets/hrnova_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

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
      return Scaffold(
        backgroundColor: context.appBg,
        body: const LoadingWidget(message: 'Starting HRNovva…'),
      );
    }

    final isLoading = signInState.isLoading;
    final errorMsg = signInState.hasError ? signInState.error.toString() : null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.appBg,
        body: SafeArea(
          child: Align(
            alignment: const Alignment(0, -1),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Wordmark row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 40, 0, 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            context.isDark
                                ? 'assets/icon/icon_dark.png'
                                : 'assets/icon/icon_light.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      'Welcome back',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: context.appText,
                                      ),
                                    ),
                                    Text(
                                      'Sign in to your account',
                                      style: TextStyle(
                                        color: context.appSubtext,
                                      ),
                                    ),
                                  ].divide(const SizedBox(height: 5)),
                                ),
                                Column(
                                  children: [
                                    HRNovaTextField(
                                      label: 'Email address',
                                      hint: 'you@company.rw',
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: AppIcons.emailOutlined,
                                      textInputAction: TextInputAction.next,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Please enter your email address';
                                        }
                                        return null;
                                      },
                                    ),
                                    HRNovaTextField(
                                      label: 'Password',
                                      hint: '••••••••',
                                      controller: _passwordController,
                                      obscureText: !_showPassword,
                                      prefixIcon: AppIcons.lockOutlineRounded,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _signIn(),
                                      suffixIcon: IconButton(
                                        icon: AppIcon(
                                          _showPassword
                                              ? AppIcons.visibilityOffOutlined
                                              : AppIcons.visibilityOutlined,
                                          color: context.appSubtext,
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
                                    if (errorMsg != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.errorRed.withAlpha(12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.errorRed.withAlpha(40)),
                                        ),
                                        child: Row(
                                          children: [
                                            const AppIcon(AppIcons.infoOutlineRounded,
                                                color: AppColors.errorRed, size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                errorMsg,
                                                style: const TextStyle(
                                                  color: AppColors.errorRed,
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    HRNovaButton(
                                      label: 'Sign In',
                                      onPressed: isLoading ? null : _signIn,
                                      isLoading: isLoading,
                                      isFullWidth: true,
                                    ),
                                  ].divide(const SizedBox(height: 15)),
                                ),
                              ].divide(const SizedBox(height: 30)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.7,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
                        child: Text(
                          'Powered by ICYEREKEZO DIGITAL Innovation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.appSubtext,
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
      ),
    );
  }
}
