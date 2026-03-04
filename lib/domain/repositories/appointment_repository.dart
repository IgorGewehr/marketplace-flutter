import '../../data/models/appointment_model.dart';

/// Appointment Repository Interface
abstract class AppointmentRepository {
  /// Get appointments (seller sees tenant's, buyer sees own)
  Future<AppointmentListResponse> getAppointments({
    int page = 1,
    int limit = 50,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? serviceId,
  });

  /// Create a new appointment (buyer books a slot)
  Future<AppointmentModel> createAppointment({
    required String serviceId,
    required String date,
    required String startTime,
    String? notes,
  });

  /// Update appointment status
  Future<AppointmentModel> updateStatus(String id, String status);

  /// Reschedule an appointment to a new date/time
  Future<AppointmentModel> reschedule(String id, String date, String startTime);

  /// Get available slots for a service on a given date
  Future<AvailableSlotsResponse> getAvailableSlots(
    String serviceId,
    String date,
  );
}

/// Response wrapper for appointment list
class AppointmentListResponse {
  final List<AppointmentModel> appointments;
  final int total;

  const AppointmentListResponse({
    required this.appointments,
    required this.total,
  });

  factory AppointmentListResponse.fromJson(Map<String, dynamic> json) {
    return AppointmentListResponse(
      appointments: (json['appointments'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((a) => AppointmentModel.fromJson(a))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }
}
