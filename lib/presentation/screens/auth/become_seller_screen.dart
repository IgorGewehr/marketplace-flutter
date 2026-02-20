import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/mercadopago_provider.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/cpf_cnpj_field.dart';
import '../../widgets/auth/phone_field.dart';
import '../../widgets/shared/app_feedback.dart';

/// Become Seller Screen - Multi-step onboarding flow (5 steps)
class BecomeSellerScreen extends ConsumerStatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  ConsumerState<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends ConsumerState<BecomeSellerScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // Step 1 - Business type
  String _businessType = ''; // 'pessoa_fisica', 'mei', 'empresa'

  // Step 2 - Business data
  final _storeNameController = TextEditingController();
  final _documentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _documentType = 'cpf';
  final _formKey = GlobalKey<FormState>();

  // Step 3 - Mercado Pago
  bool _mpConnected = false;

  // Step 4 - Confetti
  late ConfettiController _confettiController;

  bool _isSubmitting = false;

  /// Tracks whether becomeSeller was called during this flow (or user was already a seller).
  /// Used to prevent exiting in an inconsistent state.
  bool _becameSellerDuringFlow = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    // Resume at the correct step if the user is already a seller (e.g. came back after partial onboarding)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingSellerStatus();
    });
  }

  void _checkExistingSellerStatus() {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null && user.isSeller) {
      _becameSellerDuringFlow = true;
      final isMpConnected = ref.read(isMpConnectedProvider);
      if (isMpConnected) {
        setState(() => _currentStep = 4);
        _pageController.jumpToPage(4);
        _confettiController.play();
      } else {
        setState(() => _currentStep = 3);
        _pageController.jumpToPage(3);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _storeNameController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Validate before advancing
      if (!_canAdvance()) return;

      // Step 2 → create seller before advancing to OAuth
      if (_currentStep == 2) {
        _submitAndAdvance();
        return;
      }

      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Play confetti on reaching conclusion
      if (_currentStep == 4) {
        _confettiController.play();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_becameSellerDuringFlow) {
      _showExitConfirmation();
    } else {
      context.pop();
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do cadastro?'),
        content: const Text(
          'Sua loja já foi criada. Você pode conectar o Mercado Pago '
          'depois pelo painel do vendedor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continuar cadastro'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRouter.sellerDashboard);
            },
            child: const Text('Ir ao painel'),
          ),
        ],
      ),
    );
  }

  bool _canAdvance() {
    switch (_currentStep) {
      case 1:
        if (_businessType.isEmpty) {
          AppFeedback.showWarning(context, 'Selecione um tipo de negócio');
          return false;
        }
        return true;
      case 2:
        return _formKey.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  Future<void> _submitAndAdvance() async {
    setState(() => _isSubmitting = true);

    final success = await ref.read(authNotifierProvider.notifier).becomeSeller(
          tradeName: _storeNameController.text.trim(),
          documentNumber: _documentController.text.trim(),
          documentType: _documentType,
          phone: _phoneController.text.trim(),
        );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      _becameSellerDuringFlow = true;
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      AppFeedback.showError(context, 'Erro ao criar loja. Tente novamente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWelcome = _currentStep == 0;

    return PopScope(
      canPop: _currentStep == 0 && !_becameSellerDuringFlow,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentStep > 0) {
          _previousStep();
        } else {
          _showExitConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: isWelcome ? theme.colorScheme.surface : null,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and progress
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _previousStep,
                      icon: Icon(
                        Icons.arrow_back,
                        color: isWelcome ? theme.colorScheme.onSurface : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / _totalSteps,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_currentStep + 1}/$_totalSteps',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(theme),
                    _buildBusinessTypeStep(theme),
                    _buildBusinessDataStep(theme),
                    _buildMercadoPagoStep(theme),
                    _buildConclusionStep(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== Step 0: Welcome ==========
  Widget _buildWelcomeStep(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Real logo with animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Image.asset(
                'assets/images/logo.png',
                width: 160,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Venda no Compre Aqui',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Alcance milhares de clientes no Meio Oeste',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Benefits
            _BenefitItem(
              icon: Icons.trending_up_rounded,
              text: 'Acesse milhares de compradores ativos',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            _BenefitItem(
              icon: Icons.payments_outlined,
              text: 'Receba em até 2 dias úteis na sua conta',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            _BenefitItem(
              icon: Icons.phone_android_rounded,
              text: 'Gerencie tudo direto pelo celular',
              color: theme.colorScheme.primary,
            ),

            const SizedBox(height: 48),

            // CTA button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Começar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Step 1: Business Type ==========
  Widget _buildBusinessTypeStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          Text(
            'Tipo de Negócio',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Como você vai vender?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 32),

          _BusinessTypeCard(
            icon: Icons.person_outline,
            title: 'Pessoa Física',
            description: 'Venda com CPF de forma simples',
            isSelected: _businessType == 'pessoa_fisica',
            onTap: () => setState(() => _businessType = 'pessoa_fisica'),
          ),
          const SizedBox(height: 12),
          _BusinessTypeCard(
            icon: Icons.badge_outlined,
            title: 'MEI',
            description: 'Microempreendedor Individual com CNPJ',
            isSelected: _businessType == 'mei',
            onTap: () => setState(() => _businessType = 'mei'),
          ),
          const SizedBox(height: 12),
          _BusinessTypeCard(
            icon: Icons.business_outlined,
            title: 'Empresa',
            description: 'ME, EPP ou empresa com CNPJ',
            isSelected: _businessType == 'empresa',
            onTap: () => setState(() => _businessType = 'empresa'),
          ),

          const SizedBox(height: 40),

          AuthButton(
            text: 'Continuar',
            onPressed: _businessType.isNotEmpty ? _nextStep : null,
          ),
        ],
      ),
    );
  }

  // ========== Step 2: Business Data ==========
  Widget _buildBusinessDataStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Text(
              'Dados do Negócio',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preencha as informações da sua loja',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // Store name
            AuthTextField(
              controller: _storeNameController,
              label: 'Nome da Loja',
              hint: 'Ex: Brechó da Maria',
              prefixIcon: Icons.store_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o nome da loja';
                if (v.trim().length < 3) return 'Nome muito curto (mín. 3 caracteres)';
                if (v.trim().length > 60) return 'Nome muito longo (máx. 60 caracteres)';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // CPF/CNPJ
            CpfCnpjField(
              controller: _documentController,
              onTypeDetected: (type) {
                _documentType = type;
              },
            ),

            const SizedBox(height: 16),

            // Phone
            PhoneField(
              controller: _phoneController,
            ),

            const SizedBox(height: 16),

            // Address
            AuthTextField(
              controller: _addressController,
              label: 'Endereço Principal',
              hint: 'Cidade - SC',
              prefixIcon: Icons.location_on_outlined,
            ),

            const SizedBox(height: 40),

            AuthButton(
              text: 'Continuar',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _nextStep,
            ),
          ],
        ),
      ),
    );
  }

  // ========== Step 3: Mercado Pago ==========
  Widget _buildMercadoPagoStep(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          Text(
            'Mercado Pago',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Conecte para receber seus pagamentos',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 32),

          // Info cards
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.percent,
                  label: 'Taxa por venda',
                  value: '5%',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Prazo de saque',
                  value: '2 dias úteis',
                ),
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.security,
                  label: 'Split automático',
                  value: 'Ativado',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Connection status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _mpConnected
                  ? Colors.green.withAlpha(25)
                  : Colors.orange.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _mpConnected
                    ? Colors.green.withAlpha(76)
                    : Colors.orange.withAlpha(76),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _mpConnected
                      ? Icons.check_circle_outlined
                      : Icons.info_outline,
                  color: _mpConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _mpConnected
                        ? 'Mercado Pago conectado!'
                        : 'Conecte seu Mercado Pago para receber pagamentos',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Connect button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await context.push<bool>(AppRouter.sellerMpConnect);
                if (mounted) {
                  setState(() => _mpConnected = result == true);
                }
              },
              icon: const Icon(Icons.link),
              label: Text(
                _mpConnected
                    ? 'Reconectar Mercado Pago'
                    : 'Conectar com Mercado Pago',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          AuthButton(
            text: 'Continuar',
            onPressed: _mpConnected ? _nextStep : null,
          ),

          if (!_mpConnected) ...[
            const SizedBox(height: 12),
            Text(
              'A conexão com o Mercado Pago é obrigatória para receber pagamentos e vender na plataforma.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ========== Step 4: Conclusion ==========
  Widget _buildConclusionStep(ThemeData theme) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withAlpha(25),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Sua loja foi criada!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                _mpConnected
                    ? 'Tudo pronto! Você já pode começar a vender.'
                    : 'Conecte seu Mercado Pago nas configurações para começar a receber pagamentos.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              AuthButton(
                text: 'Ir para o Painel do Vendedor',
                onPressed: () => context.go(AppRouter.sellerDashboard),
              ),
            ],
          ),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
              Colors.orange,
              Colors.purple,
              Colors.pink,
            ],
            numberOfParticles: 30,
            gravity: 0.1,
          ),
        ),
      ],
    );
  }
}

// ========== Helper Widgets ==========

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool onAzure;

  const _BenefitItem({
    required this.icon,
    required this.text,
    required this.color,
    this.onAzure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: onAzure ? Colors.white.withAlpha(40) : color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: onAzure
                ? const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontSize: 14,
                  )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
          ),
        ),
      ],
    );
  }
}

class _BusinessTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _BusinessTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(13)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(50),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withAlpha(25)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
