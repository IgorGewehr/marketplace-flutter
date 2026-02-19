/// Modelo de conexão OAuth do vendedor com Mercado Pago
class MpConnectionModel {
  final bool isConnected;
  final int? mpUserId;
  final DateTime? connectedAt;

  const MpConnectionModel({
    required this.isConnected,
    this.mpUserId,
    this.connectedAt,
  });

  factory MpConnectionModel.disconnected() {
    return const MpConnectionModel(isConnected: false);
  }

  factory MpConnectionModel.fromJson(Map<String, dynamic> json) {
    return MpConnectionModel(
      isConnected: json['isConnected'] as bool? ?? false,
      mpUserId: json['mpUserId'] as int?,
      connectedAt: json['connectedAt'] != null
          ? DateTime.tryParse(json['connectedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isConnected': isConnected,
      if (mpUserId != null) 'mpUserId': mpUserId,
      if (connectedAt != null) 'connectedAt': connectedAt!.toIso8601String(),
    };
  }

  MpConnectionModel copyWith({
    bool? isConnected,
    int? mpUserId,
    DateTime? connectedAt,
  }) {
    return MpConnectionModel(
      isConnected: isConnected ?? this.isConnected,
      mpUserId: mpUserId ?? this.mpUserId,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }
}
