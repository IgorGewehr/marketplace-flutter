/// Appointment model for service scheduling
library;

import 'package:flutter/material.dart';
import '../../core/utils/firestore_utils.dart';

class AppointmentModel {
  final String id;
  final String serviceId;
  final String serviceName;
  final String tenantId;
  final String buyerUserId;
  final String buyerName;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String status; // pending, confirmed, cancelled, completed, no_show
  final String? notes;
  final String? chatId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppointmentModel({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.tenantId,
    required this.buyerUserId,
    required this.buyerName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.chatId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isNoShow => status == 'no_show';

  bool get isPast {
    final now = DateTime.now();
    final parts = date.split('-');
    if (parts.length != 3) return false;
    final timeParts = endTime.split(':');
    if (timeParts.length != 2) return false;
    final dt = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
    return dt.isBefore(now);
  }

  String get displayDate {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String get displayTime => '$startTime - $endTime';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'confirmed':
        return 'Confirmado';
      case 'cancelled':
        return 'Cancelado';
      case 'completed':
        return 'Concluído';
      case 'no_show':
        return 'Não compareceu';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.green;
      case 'no_show':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      buyerUserId: json['buyerUserId'] as String? ?? '',
      buyerName: json['buyerName'] as String? ?? '',
      date: json['date'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      chatId: json['chatId'] as String?,
      createdAt: parseFirestoreDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'tenantId': tenantId,
      'buyerUserId': buyerUserId,
      'buyerName': buyerName,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      if (notes != null) 'notes': notes,
      if (chatId != null) 'chatId': chatId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? serviceId,
    String? serviceName,
    String? tenantId,
    String? buyerUserId,
    String? buyerName,
    String? date,
    String? startTime,
    String? endTime,
    String? status,
    String? notes,
    String? chatId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      tenantId: tenantId ?? this.tenantId,
      buyerUserId: buyerUserId ?? this.buyerUserId,
      buyerName: buyerName ?? this.buyerName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      chatId: chatId ?? this.chatId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Slot model for available time slots
class TimeSlotModel {
  final String startTime;
  final String endTime;
  final bool available;

  const TimeSlotModel({
    required this.startTime,
    required this.endTime,
    required this.available,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      available: json['available'] as bool? ?? false,
    );
  }
}

/// Response for available slots endpoint
class AvailableSlotsResponse {
  final String date;
  final String dayOfWeek;
  final List<TimeSlotModel> slots;

  const AvailableSlotsResponse({
    required this.date,
    required this.dayOfWeek,
    required this.slots,
  });

  factory AvailableSlotsResponse.fromJson(Map<String, dynamic> json) {
    return AvailableSlotsResponse(
      date: json['date'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String? ?? '',
      slots: (json['slots'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((s) => TimeSlotModel.fromJson(s))
              .toList() ??
          [],
    );
  }
}
