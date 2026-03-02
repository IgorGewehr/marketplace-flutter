import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/service_model.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../shared/app_feedback.dart';

/// Booking section for service details — shows date picker + time slots
class BookingSection extends ConsumerStatefulWidget {
  final ServiceModel service;

  const BookingSection({super.key, required this.service});

  @override
  ConsumerState<BookingSection> createState() => _BookingSectionState();
}

class _BookingSectionState extends ConsumerState<BookingSection> {
  String? _selectedDate;
  String? _selectedSlot;
  final _notesController = TextEditingController();
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    // Select first available date
    final today = DateTime.now();
    for (int i = 0; i < 14; i++) {
      final date = today.add(Duration(days: i));
      if (_isDayAvailable(date)) {
        _selectedDate = DateFormat('yyyy-MM-dd').format(date);
        break;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool _isDayAvailable(DateTime date) {
    final dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    final dayName = dayNames[date.weekday % 7];
    final availableDays = widget.service.availableDays;
    if (availableDays.isEmpty) return true;
    return availableDays.contains(dayName);
  }

  Future<void> _confirmBooking() async {
    if (_selectedDate == null || _selectedSlot == null) return;

    final isAuth = ref.read(isAuthenticatedProvider);
    if (!isAuth) {
      context.push('${AppRouter.login}?redirect=/service/${widget.service.id}');
      return;
    }

    setState(() => _isBooking = true);

    try {
      final repo = ref.read(appointmentRepositoryProvider);
      final appointment = await repo.createAppointment(
        serviceId: widget.service.id,
        date: _selectedDate!,
        startTime: _selectedSlot!,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        _showSuccessDialog(appointment);
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('409')
            ? 'Horário já reservado. Escolha outro.'
            : 'Erro ao agendar. Tente novamente.';
        AppFeedback.showError(context, message);
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showSuccessDialog(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        ),
        title: const Text('Agendamento Solicitado!'),
        content: Text(
          'Seu agendamento para ${appointment.displayDate} às ${appointment.startTime} '
          'foi enviado. O prestador irá confirmar em breve.',
          textAlign: TextAlign.center,
        ),
        actions: [
          if (appointment.chatId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/chats/${appointment.chatId}');
              },
              child: const Text('Abrir Chat'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Section title
        Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Agendar Horário',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Date picker — horizontal scroll
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index));
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final isAvailable = _isDayAvailable(date);
              final isSelected = dateStr == _selectedDate;

              final dayNames = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
              final dayLabel = dayNames[date.weekday % 7];

              return GestureDetector(
                onTap: isAvailable
                    ? () {
                        setState(() {
                          _selectedDate = dateStr;
                          _selectedSlot = null;
                        });
                      }
                    : null,
                child: Container(
                  width: 56,
                  margin: EdgeInsets.only(right: index < 13 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isAvailable
                            ? theme.colorScheme.surface
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : isAvailable
                              ? theme.colorScheme.outline.withAlpha(40)
                              : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurfaceVariant.withAlpha(80),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withAlpha(80),
                        ),
                      ),
                      Text(
                        DateFormat('MMM', 'pt_BR').format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white70
                              : isAvailable
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurfaceVariant.withAlpha(80),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Time slots
        if (_selectedDate != null) _buildSlots(theme),

        // Notes field
        if (_selectedSlot != null) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Observações (opcional)',
              hintText: 'Alguma informação adicional?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 2,
            maxLength: 200,
          ),
        ],

        // Confirm button
        if (_selectedSlot != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isBooking ? null : _confirmBooking,
              icon: _isBooking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isBooking ? 'Agendando...' : 'Confirmar Agendamento'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSlots(ThemeData theme) {
    final slotsAsync = ref.watch(
      availableSlotsProvider((serviceId: widget.service.id, date: _selectedDate!)),
    );

    return slotsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Erro ao carregar horários'),
      ),
      data: (response) {
        final slots = response.slots;

        if (slots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Nenhum horário disponível neste dia',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horários disponíveis',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.map((slot) {
                final isSelected = _selectedSlot == slot.startTime;
                return ChoiceChip(
                  label: Text(slot.startTime),
                  selected: isSelected,
                  onSelected: slot.available
                      ? (_) {
                          setState(() {
                            _selectedSlot = isSelected ? null : slot.startTime;
                          });
                        }
                      : null,
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: slot.available
                      ? theme.colorScheme.surface
                      : theme.colorScheme.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : slot.available
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withAlpha(80),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : slot.available
                            ? theme.colorScheme.outline.withAlpha(40)
                            : Colors.transparent,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
