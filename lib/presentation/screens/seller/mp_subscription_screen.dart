import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../../providers/mercadopago_provider.dart';
import '../../widgets/card_payment_form.dart';

/// Tela de assinaturas da plataforma.
///
/// Vendedores escolhem um plano (Basic, Pro, Enterprise) e pagam
/// via PIX ou cartão de crédito.
class MpSubscriptionScreen extends ConsumerStatefulWidget {
  const MpSubscriptionScreen({super.key});

  @override
  ConsumerState<MpSubscriptionScreen> createState() =>
      _MpSubscriptionScreenState();
}

class _MpSubscriptionScreenState extends ConsumerState<MpSubscriptionScreen> {
  String? _selectedPlan;
  String _paymentMethod = 'pix'; // pix or card
  bool _isCreating = false;
  String? _error;

  static const _plans = [
    _PlanInfo(
      type: 'basic',
      name: 'Basic',
      price: 49.90,
      features: [
        'Até 50 produtos',
        'Relatórios básicos',
        'Suporte por email',
      ],
    ),
    _PlanInfo(
      type: 'pro',
      name: 'Pro',
      price: 99.90,
      features: [
        'Produtos ilimitados',
        'Relatórios avançados',
        'Suporte prioritário',
        'Cupons de desconto',
      ],
      isPopular: true,
    ),
    _PlanInfo(
      type: 'enterprise',
      name: 'Enterprise',
      price: 199.90,
      features: [
        'Tudo do Pro',
        'API personalizada',
        'Gerente de conta dedicado',
        'SLA garantido',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = ref.watch(mpSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assinatura'),
      ),
      body: subscription.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (current) {
          if (current != null && !current.isCancelled) {
            return _buildCurrentSubscription(theme, current);
          }
          return _buildPlanSelection(theme);
        },
      ),
    );
  }

  Widget _buildCurrentSubscription(ThemeData theme, dynamic subscription) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withAlpha(200),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plano Atual',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subscription.planType.toString().toUpperCase(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.currency(subscription.amount),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Status: ${subscription.status}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                if (subscription.nextPaymentDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Próximo pagamento: ${subscription.nextPaymentDate}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmCancelSubscription(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancelar assinatura'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelection(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escolha seu plano',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Comece a vender no marketplace',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Plan cards
          ..._plans.map((plan) => _PlanCard(
                plan: plan,
                isSelected: _selectedPlan == plan.type,
                onTap: () => setState(() => _selectedPlan = plan.type),
              )),

          if (_selectedPlan != null) ...[
            const SizedBox(height: 24),

            Text(
              'Forma de pagamento',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Payment method selection
            Row(
              children: [
                Expanded(
                  child: _PaymentOptionCard(
                    icon: Icons.pix,
                    label: 'PIX',
                    isSelected: _paymentMethod == 'pix',
                    onTap: () => setState(() => _paymentMethod = 'pix'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaymentOptionCard(
                    icon: Icons.credit_card,
                    label: 'Cartão',
                    isSelected: _paymentMethod == 'card',
                    onTap: () => setState(() => _paymentMethod = 'card'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_paymentMethod == 'card')
              CardPaymentForm(
                onTokenized: (tokenId) => _createSubscription(tokenId),
                isLoading: _isCreating,
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isCreating ? null : () => _createSubscription(null),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Assinar via PIX'),
                ),
              ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createSubscription(String? cardTokenId) async {
    if (_selectedPlan == null) return;

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(mpSubscriptionProvider.notifier)
          .create(_selectedPlan!, cardTokenId: cardTokenId);

      if (mounted) {
        // If PIX, open initPoint in WebView
        if (_paymentMethod == 'pix' && result.initPoint != null) {
          _openPixSubscription(result.initPoint!);
        } else {
          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
            const SnackBar(content: Text('Assinatura criada com sucesso!')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao criar assinatura: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _openPixSubscription(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Pagamento PIX')),
          body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadRequest(Uri.parse(url)),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancelSubscription(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar assinatura?'),
        content: const Text(
          'Ao cancelar, você perderá acesso aos benefícios do plano atual ao final do período.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancelar assinatura'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(mpSubscriptionProvider.notifier).cancel();
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(content: Text('Assinatura cancelada')),
        );
      }
    }
  }
}

class _PlanInfo {
  final String type;
  final String name;
  final double price;
  final List<String> features;
  final bool isPopular;

  const _PlanInfo({
    required this.type,
    required this.name,
    required this.price,
    required this.features,
    this.isPopular = false,
  });
}

class _PlanCard extends StatelessWidget {
  final _PlanInfo plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(30),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (plan.isPopular)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'POPULAR',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${Formatters.currency(plan.price)}/mês',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(f, style: theme.textTheme.bodySmall),
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

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.icon,
    required this.label,
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
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(30),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
