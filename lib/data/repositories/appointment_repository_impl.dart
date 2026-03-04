import '../../core/constants/api_constants.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/api_client.dart';
import '../models/appointment_model.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  final ApiClient _apiClient;

  AppointmentRepositoryImpl(this._apiClient);

  @override
  Future<AppointmentListResponse> getAppointments({
    int page = 1,
    int limit = 50,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? serviceId,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status != 'all') queryParams['status'] = status;
    if (dateFrom != null) queryParams['dateFrom'] = dateFrom;
    if (dateTo != null) queryParams['dateTo'] = dateTo;
    if (serviceId != null) queryParams['serviceId'] = serviceId;

    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.appointments,
      queryParameters: queryParams,
    );

    return AppointmentListResponse.fromJson(response);
  }

  @override
  Future<AppointmentModel> createAppointment({
    required String serviceId,
    required String date,
    required String startTime,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'serviceId': serviceId,
      'date': date,
      'startTime': startTime,
    };
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.appointments,
      data: body,
    );

    return AppointmentModel.fromJson(response);
  }

  @override
  Future<AppointmentModel> updateStatus(String id, String status) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.appointmentById(id),
      data: {'status': status},
    );

    return AppointmentModel.fromJson(response);
  }

  @override
  Future<AppointmentModel> reschedule(String id, String date, String startTime) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      '${ApiConstants.appointmentById(id)}/reschedule',
      data: {'date': date, 'startTime': startTime},
    );
    return AppointmentModel.fromJson(response);
  }

  @override
  Future<AvailableSlotsResponse> getAvailableSlots(
    String serviceId,
    String date,
  ) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.serviceSlots(serviceId),
      queryParameters: {'date': date},
    );

    return AvailableSlotsResponse.fromJson(response);
  }
}
