/// Transaction model matching SCHEMA.md
library;

class TransactionModel {
  final String id;
  final String tenantId;
  final String type; // sale, refund, withdrawal, fee
  final String source; // marketplace, pos
  final double amount;
  final double fee;
  final double netAmount;
  final String description;
  final String status; // pending, completed, failed
  final String? orderId;
  final String? invoiceId;
  final String? walletId;
  final String? gatewayTransactionId;
  final String? gatewayProvider;
  final TransactionMetadata? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.tenantId,
    required this.type,
    this.source = 'marketplace',
    required this.amount,
    this.fee = 0.0,
    required this.netAmount,
    required this.description,
    this.status = 'completed',
    this.orderId,
    this.invoiceId,
    this.walletId,
    this.gatewayTransactionId,
    this.gatewayProvider,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if transaction is a sale
  bool get isSale => type == 'sale';

  /// Check if transaction is a refund
  bool get isRefund => type == 'refund';

  /// Check if transaction is a withdrawal
  bool get isWithdrawal => type == 'withdrawal';

  /// Check if transaction is completed
  bool get isCompleted => status == 'completed';

  /// Check if amount is positive (income)
  bool get isIncome => netAmount > 0;

  /// Check if amount is negative (expense)
  bool get isExpense => netAmount < 0;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      type: json['type'] as String? ?? 'sale',
      source: json['source'] as String? ?? 'marketplace',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
      orderId: json['orderId'] as String?,
      invoiceId: json['invoiceId'] as String?,
      walletId: json['walletId'] as String?,
      gatewayTransactionId: json['gatewayTransactionId'] as String?,
      gatewayProvider: json['gatewayProvider'] as String?,
      metadata: json['metadata'] != null
          ? TransactionMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'type': type,
      'source': source,
      'amount': amount,
      'fee': fee,
      'netAmount': netAmount,
      'description': description,
      'status': status,
      if (orderId != null) 'orderId': orderId,
      if (invoiceId != null) 'invoiceId': invoiceId,
      if (walletId != null) 'walletId': walletId,
      if (gatewayTransactionId != null) 'gatewayTransactionId': gatewayTransactionId,
      if (gatewayProvider != null) 'gatewayProvider': gatewayProvider,
      if (metadata != null) 'metadata': metadata!.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  TransactionModel copyWith({
    String? id,
    String? tenantId,
    String? type,
    String? source,
    double? amount,
    double? fee,
    double? netAmount,
    String? description,
    String? status,
    String? orderId,
    String? invoiceId,
    String? walletId,
    String? gatewayTransactionId,
    String? gatewayProvider,
    TransactionMetadata? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      type: type ?? this.type,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      fee: fee ?? this.fee,
      netAmount: netAmount ?? this.netAmount,
      description: description ?? this.description,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      invoiceId: invoiceId ?? this.invoiceId,
      walletId: walletId ?? this.walletId,
      gatewayTransactionId: gatewayTransactionId ?? this.gatewayTransactionId,
      gatewayProvider: gatewayProvider ?? this.gatewayProvider,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TransactionMetadata {
  final String? paymentMethod;
  final FeeBreakdown? feeBreakdown;

  const TransactionMetadata({
    this.paymentMethod,
    this.feeBreakdown,
  });

  factory TransactionMetadata.fromJson(Map<String, dynamic> json) {
    return TransactionMetadata(
      paymentMethod: json['paymentMethod'] as String?,
      feeBreakdown: json['feeBreakdown'] != null
          ? FeeBreakdown.fromJson(json['feeBreakdown'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (feeBreakdown != null) 'feeBreakdown': feeBreakdown!.toJson(),
    };
  }
}

class FeeBreakdown {
  final double gateway;
  final double marketplace;

  const FeeBreakdown({
    this.gateway = 0.0,
    this.marketplace = 0.0,
  });

  double get total => gateway + marketplace;

  factory FeeBreakdown.fromJson(Map<String, dynamic> json) {
    return FeeBreakdown(
      gateway: (json['gateway'] as num?)?.toDouble() ?? 0.0,
      marketplace: (json['marketplace'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gateway': gateway,
      'marketplace': marketplace,
    };
  }
}
