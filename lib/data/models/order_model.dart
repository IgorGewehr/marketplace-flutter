/// Order model matching SCHEMA.md
library;

import 'address_model.dart';

class OrderModel {
  final String id;
  final String tenantId;
  final String buyerUserId;
  final String orderNumber;
  final String source; // marketplace, pos
  final List<OrderItemModel> items;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
  final String deliveryType; // delivery, pickup
  final AddressModel? deliveryAddress;
  final DateTime? estimatedDelivery;
  final String paymentMethod;
  final String paymentStatus; // pending, paid, failed, refunded
  final String? paymentGatewayId;
  final String status; // pending, confirmed, preparing, ready, shipped, delivered, cancelled
  final List<OrderStatusHistory> statusHistory;
  final String? customerNotes;
  final String? internalNotes;
  final String? invoiceId;
  final String? chatId;
  final String? qrCodeId; // QR Code for delivery confirmation
  final DateTime? deliveryConfirmedAt; // When buyer confirmed delivery
  final DateTime? paymentReleasedAt; // When payment was released to seller (24h after confirmation)
  final OrderPaymentSplit? paymentSplit; // Split payment configuration
  final String? pixCode; // PIX copia e cola code (from payment creation)
  final String? pixQrCodeUrl; // PIX QR code image URL
  final DateTime? pixExpiration; // PIX payment expiration
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.tenantId,
    required this.buyerUserId,
    required this.orderNumber,
    this.source = 'marketplace',
    this.items = const [],
    required this.subtotal,
    this.discount = 0,
    this.deliveryFee = 0,
    required this.total,
    this.deliveryType = 'delivery',
    this.deliveryAddress,
    this.estimatedDelivery,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.paymentGatewayId,
    this.status = 'pending',
    this.statusHistory = const [],
    this.customerNotes,
    this.internalNotes,
    this.invoiceId,
    this.chatId,
    this.qrCodeId,
    this.deliveryConfirmedAt,
    this.paymentReleasedAt,
    this.paymentSplit,
    this.pixCode,
    this.pixQrCodeUrl,
    this.pixExpiration,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if order is paid
  bool get isPaid => paymentStatus == 'paid';

  /// Check if order can be cancelled
  bool get canBeCancelled =>
      status == 'pending' || status == 'confirmed' || status == 'preparing';

  /// Check if order is completed
  bool get isCompleted => status == 'delivered';

  /// Check if order is cancelled
  bool get isCancelled => status == 'cancelled';

  /// Check if delivery was confirmed by buyer
  bool get isDeliveryConfirmed => deliveryConfirmedAt != null;

  /// Check if payment was released to seller
  bool get isPaymentReleased => paymentReleasedAt != null;

  /// Check if payment is being held (confirmed but not released yet)
  bool get isPaymentOnHold => isDeliveryConfirmed && !isPaymentReleased;

  /// Get total items quantity
  int get totalItemsQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  /// Get items count (unique products)
  int get itemsCount => items.length;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      buyerUserId: json['buyerUserId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      source: json['source'] as String? ?? 'marketplace',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      deliveryType: json['deliveryType'] as String? ?? 'delivery',
      deliveryAddress: json['deliveryAddress'] != null
          ? AddressModel.fromJson(json['deliveryAddress'] as Map<String, dynamic>)
          : null,
      estimatedDelivery: json['estimatedDelivery'] != null
          ? DateTime.parse(json['estimatedDelivery'] as String)
          : null,
      paymentMethod: json['paymentMethod'] as String? ?? '',
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      paymentGatewayId: json['paymentGatewayId'] as String?,
      status: json['status'] as String? ?? 'pending',
      statusHistory: (json['statusHistory'] as List<dynamic>?)
              ?.map((s) => OrderStatusHistory.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      customerNotes: json['customerNotes'] as String?,
      internalNotes: json['internalNotes'] as String?,
      invoiceId: json['invoiceId'] as String?,
      chatId: json['chatId'] as String?,
      qrCodeId: json['qrCodeId'] as String?,
      deliveryConfirmedAt: json['deliveryConfirmedAt'] != null
          ? DateTime.parse(json['deliveryConfirmedAt'] as String)
          : null,
      paymentReleasedAt: json['paymentReleasedAt'] != null
          ? DateTime.parse(json['paymentReleasedAt'] as String)
          : null,
      paymentSplit: json['paymentSplit'] != null
          ? OrderPaymentSplit.fromJson(json['paymentSplit'] as Map<String, dynamic>)
          : null,
      pixCode: json['pixCode'] as String?,
      pixQrCodeUrl: json['pixQrCodeUrl'] as String?,
      pixExpiration: json['pixExpiration'] != null
          ? DateTime.parse(json['pixExpiration'] as String)
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
      'buyerUserId': buyerUserId,
      'orderNumber': orderNumber,
      'source': source,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'deliveryFee': deliveryFee,
      'total': total,
      'deliveryType': deliveryType,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress!.toJson(),
      if (estimatedDelivery != null) 'estimatedDelivery': estimatedDelivery!.toIso8601String(),
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      if (paymentGatewayId != null) 'paymentGatewayId': paymentGatewayId,
      'status': status,
      'statusHistory': statusHistory.map((s) => s.toJson()).toList(),
      if (customerNotes != null) 'customerNotes': customerNotes,
      if (internalNotes != null) 'internalNotes': internalNotes,
      if (invoiceId != null) 'invoiceId': invoiceId,
      if (chatId != null) 'chatId': chatId,
      if (qrCodeId != null) 'qrCodeId': qrCodeId,
      if (deliveryConfirmedAt != null) 'deliveryConfirmedAt': deliveryConfirmedAt!.toIso8601String(),
      if (paymentReleasedAt != null) 'paymentReleasedAt': paymentReleasedAt!.toIso8601String(),
      if (paymentSplit != null) 'paymentSplit': paymentSplit!.toJson(),
      if (pixCode != null) 'pixCode': pixCode,
      if (pixQrCodeUrl != null) 'pixQrCodeUrl': pixQrCodeUrl,
      if (pixExpiration != null) 'pixExpiration': pixExpiration!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  OrderModel copyWith({
    String? id,
    String? tenantId,
    String? buyerUserId,
    String? orderNumber,
    String? source,
    List<OrderItemModel>? items,
    double? subtotal,
    double? discount,
    double? deliveryFee,
    double? total,
    String? deliveryType,
    AddressModel? deliveryAddress,
    DateTime? estimatedDelivery,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentGatewayId,
    String? status,
    List<OrderStatusHistory>? statusHistory,
    String? customerNotes,
    String? internalNotes,
    String? invoiceId,
    String? chatId,
    String? qrCodeId,
    DateTime? deliveryConfirmedAt,
    DateTime? paymentReleasedAt,
    OrderPaymentSplit? paymentSplit,
    String? pixCode,
    String? pixQrCodeUrl,
    DateTime? pixExpiration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      buyerUserId: buyerUserId ?? this.buyerUserId,
      orderNumber: orderNumber ?? this.orderNumber,
      source: source ?? this.source,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      deliveryType: deliveryType ?? this.deliveryType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentGatewayId: paymentGatewayId ?? this.paymentGatewayId,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      customerNotes: customerNotes ?? this.customerNotes,
      internalNotes: internalNotes ?? this.internalNotes,
      invoiceId: invoiceId ?? this.invoiceId,
      chatId: chatId ?? this.chatId,
      qrCodeId: qrCodeId ?? this.qrCodeId,
      deliveryConfirmedAt: deliveryConfirmedAt ?? this.deliveryConfirmedAt,
      paymentReleasedAt: paymentReleasedAt ?? this.paymentReleasedAt,
      paymentSplit: paymentSplit ?? this.paymentSplit,
      pixCode: pixCode ?? this.pixCode,
      pixQrCodeUrl: pixQrCodeUrl ?? this.pixQrCodeUrl,
      pixExpiration: pixExpiration ?? this.pixExpiration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class OrderItemModel {
  final String productId;
  final String? variantId;
  final String name;
  final String? sku;
  final String? imageUrl;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double total;

  const OrderItemModel({
    required this.productId,
    this.variantId,
    required this.name,
    this.sku,
    this.imageUrl,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.total,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['productId'] as String? ?? '',
      variantId: json['variantId'] as String?,
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      imageUrl: json['imageUrl'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      if (variantId != null) 'variantId': variantId,
      'name': name,
      if (sku != null) 'sku': sku,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'total': total,
    };
  }
}

class OrderStatusHistory {
  final String status;
  final DateTime timestamp;
  final String? note;
  final String? userId;

  const OrderStatusHistory({
    required this.status,
    required this.timestamp,
    this.note,
    this.userId,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    return OrderStatusHistory(
      status: json['status'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      note: json['note'] as String?,
      userId: json['userId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      if (note != null) 'note': note,
      if (userId != null) 'userId': userId,
    };
  }
}

/// Payment split configuration for marketplace orders
class OrderPaymentSplit {
  final double platformFeeAmount; // Platform fee (Compre Aqui)
  final double platformFeePercentage;
  final double sellerAmount; // Amount that goes to seller
  final String? mpPaymentId; // Mercado Pago payment ID
  final String? mpSplitPaymentId; // Mercado Pago split payment ID
  final String status; // pending, held, released
  final DateTime? heldUntil; // Release date (24h after delivery confirmation)

  const OrderPaymentSplit({
    required this.platformFeeAmount,
    required this.platformFeePercentage,
    required this.sellerAmount,
    this.mpPaymentId,
    this.mpSplitPaymentId,
    this.status = 'pending',
    this.heldUntil,
  });

  /// Check if payment is held
  bool get isHeld => status == 'held';

  /// Check if payment is released
  bool get isReleased => status == 'released';

  factory OrderPaymentSplit.fromJson(Map<String, dynamic> json) {
    return OrderPaymentSplit(
      platformFeeAmount: (json['platformFeeAmount'] as num?)?.toDouble() ?? 0.0,
      platformFeePercentage: (json['platformFeePercentage'] as num?)?.toDouble() ?? 0.0,
      sellerAmount: (json['sellerAmount'] as num?)?.toDouble() ?? 0.0,
      mpPaymentId: json['mpPaymentId'] as String?,
      mpSplitPaymentId: json['mpSplitPaymentId'] as String?,
      status: json['status'] as String? ?? 'pending',
      heldUntil: json['heldUntil'] != null
          ? DateTime.parse(json['heldUntil'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platformFeeAmount': platformFeeAmount,
      'platformFeePercentage': platformFeePercentage,
      'sellerAmount': sellerAmount,
      if (mpPaymentId != null) 'mpPaymentId': mpPaymentId,
      if (mpSplitPaymentId != null) 'mpSplitPaymentId': mpSplitPaymentId,
      'status': status,
      if (heldUntil != null) 'heldUntil': heldUntil!.toIso8601String(),
    };
  }
}
