import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/appointment_model.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/seller/appointment_card.dart';
import '../../widgets/shared/app_feedback.dart';

class SellerAgendaScreen extends ConsumerWidget {
  const SellerAgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(sellerAppointmentFilterProvider);
    final appointmentsAsync = ref.watch(filteredSellerAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.sellerAccent,
        onRefresh: () => ref.read(sellerAppointmentsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text(
                'Agenda',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _FilterChips(
                  selected: filter,
                  onSelected: (value) {
                    ref.read(sellerAppointmentFilterProvider.notifier).state = value;
                  },
                ),
              ),
            ),

            // Content
            appointmentsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: _AgendaShimmer(),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      const Text('Erro ao carregar agenda'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(sellerAppointmentsProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(filter: filter),
                  );
                }

                // Group by date
                final grouped = _groupByDate(appointments);
                final now = DateTime.now();
                final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = grouped.entries.elementAt(index);
                        final date = entry.key;
                        final items = entry.value;

                        String sectionTitle;
                        if (date == todayStr) {
                          sectionTitle = 'Hoje';
                        } else {
                          final tomorrow = now.add(const Duration(days: 1));
                          final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
                          if (date == tomorrowStr) {
                            sectionTitle = 'Amanhã';
                          } else {
                            final parts = date.split('-');
                            sectionTitle = '${parts[2]}/${parts[1]}/${parts[0]}';
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0) const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                sectionTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            ...items.asMap().entries.map((e) {
                              final apt = e.value;
                              return AppointmentCard(
                                appointment: apt,
                                onConfirm: apt.isPending
                                    ? () => _updateStatus(context, ref, apt, 'confirmed')
                                    : null,
                                onCancel: (apt.isPending || apt.isConfirmed)
                                    ? () => _updateStatus(context, ref, apt, 'cancelled')
                                    : null,
                                onComplete: apt.isConfirmed
                                    ? () => _updateStatus(context, ref, apt, 'completed')
                                    : null,
                                onNoShow: apt.isConfirmed
                                    ? () => _updateStatus(context, ref, apt, 'no_show')
                                    : null,
                                onTap: apt.chatId != null
                                    ? () => context.push('/chats/${apt.chatId}')
                                    : null,
                              ).animate(delay: Duration(milliseconds: e.key * 60))
                                  .fadeIn(duration: 300.ms)
                                  .slideY(begin: 0.05, end: 0, duration: 300.ms);
                            }),
                          ],
                        );
                      },
                      childCount: grouped.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<AppointmentModel>> _groupByDate(List<AppointmentModel> appointments) {
    final map = <String, List<AppointmentModel>>{};
    for (final apt in appointments) {
      map.putIfAbsent(apt.date, () => []).add(apt);
    }
    return map;
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
    String status,
  ) async {
    try {
      await ref.read(sellerAppointmentsProvider.notifier).updateStatus(
            appointment.id,
            status,
          );
      if (context.mounted) {
        final messages = {
          'confirmed': 'Agendamento confirmado!',
          'cancelled': 'Agendamento cancelado',
          'completed': 'Serviço concluído!',
          'no_show': 'Não comparecimento registrado',
        };
        AppFeedback.showSuccess(context, messages[status] ?? 'Atualizado');
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'Erro ao atualizar agendamento');
      }
    }
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'Todos'),
      ('pending', 'Pendentes'),
      ('confirmed', 'Confirmados'),
      ('completed', 'Concluídos'),
      ('cancelled', 'Cancelados'),
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = filters[index];
          final isSelected = selected == value;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onSelected(value),
            selectedColor: Colors.white,
            backgroundColor: Colors.white.withAlpha(40),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.sellerAccent : Colors.white,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
            side: BorderSide(
              color: isSelected ? Colors.white : Colors.white.withAlpha(60),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = filter == 'all'
        ? 'Nenhum agendamento ainda'
        : 'Nenhum agendamento ${_filterLabel(filter).toLowerCase()}';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 64,
            color: AppColors.textHint,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quando clientes agendarem serviços,\neles aparecerão aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'pending':
        return 'Pendente';
      case 'confirmed':
        return 'Confirmado';
      case 'completed':
        return 'Concluído';
      case 'cancelled':
        return 'Cancelado';
      default:
        return '';
    }
  }
}

class _AgendaShimmer extends StatelessWidget {
  const _AgendaShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              4,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
