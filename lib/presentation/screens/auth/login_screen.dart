import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/social_login_buttons.dart';

/// Login Screen — branded Compre aQUI experience
class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectPath;

  const LoginScreen({super.key, this.redirectPath});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      _navigateAfterLogin();
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);

    try {
      final success =
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        _navigateAfterLogin();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
    }
  }

  void _navigateAfterLogin() {
    final redirect = widget.redirectPath;
    if (redirect != null &&
        redirect.isNotEmpty &&
        redirect.startsWith('/') &&
        !redirect.contains('://')) {
      context.go(redirect);
    } else {
      context.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Column(
          children: [
            // ── Green gradient header ──
            SizedBox(
              height: topPadding + 200,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Back button
                      _GlassBackButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRouter.home);
                          }
                        },
                      ),
                      const Spacer(),
                      // Logo + welcome text
                      Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 56,
                              fit: BoxFit.contain,
                            )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .scale(
                                  begin: const Offset(0.8, 0.8),
                                  end: const Offset(1, 1),
                                  duration: 500.ms,
                                  curve: Curves.easeOutBack,
                                ),
                            const SizedBox(height: 12),
                            Text(
                              'Bem-vindo de volta!',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 400.ms)
                                .slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 4),
                            Text(
                              'Entre para continuar comprando',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withAlpha(200),
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 300.ms, duration: 400.ms),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // ── White form card ──
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                      children: [
                        // Email field
                        AuthTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'seu@email.com',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.validateEmail,
                          enabled: !isLoading,
                          autofillHints: const [AutofillHints.email],
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 20),

                        // Password field
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Senha',
                          hint: '••••••••',
                          prefixIcon: Icons.lock_outlined,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe sua senha';
                            }
                            return null;
                          },
                          enabled: !isLoading,
                          onSubmitted: (_) => _handleLogin(),
                          autofillHints: const [AutofillHints.password],
                        )
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () => context.push(AppRouter.forgotPassword),
                            child: Text(
                              'Esqueci minha senha',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Error message
                        if (authState.hasError)
                          _ErrorBanner(
                            message: getAuthErrorMessage(authState.error!),
                          ),

                        // Login button
                        AuthButton(
                          text: 'Entrar',
                          onPressed: isLoading ? null : _handleLogin,
                          isLoading: isLoading && !_isGoogleLoading,
                        )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 28),

                        // Divider
                        const AuthDivider()
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 400.ms),

                        const SizedBox(height: 28),

                        // Google login
                        SocialLoginButtons(
                          onGooglePressed: isLoading ? null : _handleGoogleLogin,
                          isLoading: _isGoogleLoading,
                        )
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 32),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Não tem conta? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: isLoading
                                  ? null
                                  : () => context.push(AppRouter.register),
                              child: Text(
                                'Criar conta',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 700.ms, duration: 400.ms),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ──

/// Frosted-glass back button for gradient backgrounds
class _GlassBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GlassBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withAlpha(60),
          ),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

/// Animated error banner for auth forms
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).shake(hz: 2, duration: 400.ms);
  }
}
