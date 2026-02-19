/// Modelo de assinatura do vendedor na plataforma
class MpSubscriptionModel {
  final String id;
  final String mpSubscriptionId;
  final String planType; // basic, pro, enterprise
  final String status; // pending, authorized, paused, cancelled
  final double amount;
  final String? nextPaymentDate;
  final String? initPoint;

  const MpSubscriptionModel({
    required this.id,
    required this.mpSubscriptionId,
    required this.planType,
    required this.status,
    required this.amount,
    this.nextPaymentDate,
    this.initPoint,
  });

  factory MpSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return MpSubscriptionModel(
      id: json['id'] as String? ?? '',
      mpSubscriptionId: json['mpSubscriptionId'] as String? ?? '',
      planType: json['planType'] as String? ?? 'basic',
      status: json['status'] as String? ?? 'pending',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      nextPaymentDate: json['nextPaymentDate'] as String?,
      initPoint: json['initPoint'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mpSubscriptionId': mpSubscriptionId,
      'planType': planType,
      'status': status,
      'amount': amount,
      if (nextPaymentDate != null) 'nextPaymentDate': nextPaymentDate,
      if (initPoint != null) 'initPoint': initPoint,
    };
  }

  MpSubscriptionModel copyWith({
    String? id,
    String? mpSubscriptionId,
    String? planType,
    String? status,
    double? amount,
    String? nextPaymentDate,
    String? initPoint,
  }) {
    return MpSubscriptionModel(
      id: id ?? this.id,
      mpSubscriptionId: mpSubscriptionId ?? this.mpSubscriptionId,
      planType: planType ?? this.planType,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
      initPoint: initPoint ?? this.initPoint,
    );
  }

  bool get isActive => status == 'authorized';
  bool get isPending => status == 'pending';
  bool get isPaused => status == 'paused';
  bool get isCancelled => status == 'cancelled';
}
