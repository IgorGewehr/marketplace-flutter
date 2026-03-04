import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/appointment_model.dart';
import 'core_providers.dart';

// ============================================================================
// Filter
// ============================================================================

final sellerAppointmentFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

// ============================================================================
// Seller Appointments
// ============================================================================

final sellerAppointmentsProvider =
    AsyncNotifierProvider.autoDispose<SellerAppointmentsNotifier, List<AppointmentModel>>(
  SellerAppointmentsNotifier.new,
);

class SellerAppointmentsNotifier extends AutoDisposeAsyncNotifier<List<AppointmentModel>> {
  @override
  Future<List<AppointmentModel>> build() async {
    final repo = ref.watch(appointmentRepositoryProvider);
    final response = await repo.getAppointments(limit: 100);
    return response.appointments;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(appointmentRepositoryProvider);
      final response = await repo.getAppointments(limit: 100);
      return response.appointments;
    });
  }

  Future<void> updateStatus(String id, String status) async {
    final repo = ref.read(appointmentRepositoryProvider);
    final updated = await repo.updateStatus(id, status);
    state = AsyncData([
      for (final apt in state.valueOrNull ?? [])
        apt.id == id ? updated : apt,
    ]);
  }

  Future<void> reschedule(String id, String date, String startTime) async {
    final repo = ref.read(appointmentRepositoryProvider);
    final updated = await repo.reschedule(id, date, startTime);
    state = AsyncData([
      for (final apt in state.valueOrNull ?? [])
        apt.id == id ? updated : apt,
    ]);
  }
}

// ============================================================================
// Filtered Seller Appointments
// ============================================================================

final filteredSellerAppointmentsProvider = Provider.autoDispose<AsyncValue<List<AppointmentModel>>>((ref) {
  final filter = ref.watch(sellerAppointmentFilterProvider);
  final appointmentsAsync = ref.watch(sellerAppointmentsProvider);

  return appointmentsAsync.whenData((appointments) {
    if (filter == 'all') return appointments;
    return appointments.where((a) => a.status == filter).toList();
  });
});

// ============================================================================
// Today's Appointments Count (for badge)
// ============================================================================

final todayAppointmentsCountProvider = Provider.autoDispose<int>((ref) {
  final appointmentsAsync = ref.watch(sellerAppointmentsProvider);
  final appointments = appointmentsAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  return appointments
      .where((a) => a.date == today && (a.isPending || a.isConfirmed))
      .length;
});

// ============================================================================
// Buyer Appointments
// ============================================================================

final buyerAppointmentsProvider =
    AsyncNotifierProvider.autoDispose<BuyerAppointmentsNotifier, List<AppointmentModel>>(
  BuyerAppointmentsNotifier.new,
);

class BuyerAppointmentsNotifier extends AutoDisposeAsyncNotifier<List<AppointmentModel>> {
  @override
  Future<List<AppointmentModel>> build() async {
    final repo = ref.watch(appointmentRepositoryProvider);
    final response = await repo.getAppointments(limit: 50);
    return response.appointments;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(appointmentRepositoryProvider);
      final response = await repo.getAppointments(limit: 50);
      return response.appointments;
    });
  }
}

// ============================================================================
// Available Slots
// ============================================================================

final availableSlotsProvider =
    FutureProvider.autoDispose.family<AvailableSlotsResponse, ({String serviceId, String date})>(
  (ref, params) async {
    final repo = ref.watch(appointmentRepositoryProvider);
    return repo.getAvailableSlots(params.serviceId, params.date);
  },
);
