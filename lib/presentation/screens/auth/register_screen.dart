import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/social_login_buttons.dart';

/// Register Screen — branded Compre aQUI experience
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _acceptedTerms = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      AppFeedback.showWarning(
        context,
        'Você precisa aceitar os termos de uso para continuar',
        title: 'Termos não aceitos',
      );
      return;
    }

    try {
      final success = await ref.read(authNotifierProvider.notifier).register(
            displayName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      if (success) {
        AppFeedback.showSuccess(
          context,
          'Conta criada com sucesso!',
          title: 'Bem-vindo!',
        );
        context.go(AppRouter.home);
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(
        context,
        e.toString(),
        title: 'Erro ao criar conta',
      );
    }
  }

  Future<void> _handleGoogleRegister() async {
    setState(() => _isGoogleLoading = true);

    try {
      final success =
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (success) {
        context.go(AppRouter.home);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
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
              height: topPadding + 170,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _GlassBackButton(
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Center(
                        child: Column(
                          children: [
                            // Icon instead of logo (shorter header for register)
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withAlpha(60),
                                ),
                              ),
                              child: const Icon(
                                Icons.person_add_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
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
                              'Criar conta',
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
                              'Rápido e fácil, em poucos passos',
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
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Google sign-up first (quick option)
                        SocialLoginButtons(
                          onGooglePressed:
                              isLoading ? null : _handleGoogleRegister,
                          isLoading: _isGoogleLoading,
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 24),

                        const AuthDivider(text: 'ou cadastre com email')
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms),

                        const SizedBox(height: 24),

                        // Name field
                        AuthTextField(
                          controller: _nameController,
                          label: 'Nome completo',
                          hint: 'João Silva',
                          prefixIcon: Icons.person_outline,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          validator: Validators.validateName,
                          enabled: !isLoading,
                        )
                            .animate()
                            .fadeIn(delay: 350.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 16),

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
                        )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 16),

                        // Password field
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Senha',
                          hint: 'Mínimo 6 caracteres',
                          prefixIcon: Icons.lock_outlined,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: Validators.validatePassword,
                          enabled: !isLoading,
                        )
                            .animate()
                            .fadeIn(delay: 450.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 16),

                        // Confirm password field
                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar senha',
                          hint: 'Repita a senha',
                          prefixIcon: Icons.lock_outlined,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) =>
                              Validators.validatePasswordConfirmation(
                            value,
                            _passwordController.text,
                          ),
                          enabled: !isLoading,
                          onSubmitted: (_) => _handleRegister(),
                        )
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 16),

                        // Terms checkbox
                        _TermsCheckbox(
                          accepted: _acceptedTerms,
                          isLoading: isLoading,
                          onChanged: (value) {
                            setState(() => _acceptedTerms = value);
                          },
                        )
                            .animate()
                            .fadeIn(delay: 550.ms, duration: 400.ms),

                        const SizedBox(height: 20),

                        // Error message
                        if (authState.hasError)
                          _ErrorBanner(
                            message: getAuthErrorMessage(authState.error!),
                          ),

                        // Register button
                        AuthButton(
                          text: 'Criar conta',
                          onPressed: isLoading ? null : _handleRegister,
                          isLoading: isLoading && !_isGoogleLoading,
                        )
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 400.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 28),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Já tem conta? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: isLoading
                                  ? null
                                  : () => context.go(AppRouter.login),
                              child: Text(
                                'Entrar',
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

                        const SizedBox(height: 24),
                      ],
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

class _TermsCheckbox extends StatelessWidget {
  final bool accepted;
  final bool isLoading;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({
    required this.accepted,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isLoading ? null : () => onChanged(!accepted),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accepted
              ? AppColors.primary.withAlpha(8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accepted
                ? AppColors.primary.withAlpha(40)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: accepted ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accepted ? AppColors.primary : AppColors.textHint,
                  width: 1.5,
                ),
              ),
              child: accepted
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Li e aceito os '),
                    TextSpan(
                      text: 'Termos de Uso',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' e '),
                    TextSpan(
                      text: 'Política de Privacidade',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
