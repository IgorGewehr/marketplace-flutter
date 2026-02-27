/// Chat and Message models matching SCHEMA.md
library;

import '../../core/utils/firestore_utils.dart';

class ChatModel {
  final String id;
  final String tenantId;
  final String buyerUserId;
  final String? orderId;
  final String? tenantName;
  final String? buyerName;
  final String status; // active, closed, archived
  final LastMessage? lastMessage;
  final int unreadByBuyer;
  final int unreadByTenant;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime updatedAt;
  // typingUsers: map of userId -> last-typed ISO timestamp string
  final Map<String, String> typingUsers;

  const ChatModel({
    required this.id,
    required this.tenantId,
    required this.buyerUserId,
    this.orderId,
    this.tenantName,
    this.buyerName,
    this.status = 'active',
    this.lastMessage,
    this.unreadByBuyer = 0,
    this.unreadByTenant = 0,
    this.participants = const [],
    required this.createdAt,
    required this.updatedAt,
    this.typingUsers = const {},
  });

  /// Check if chat is active
  bool get isActive => status == 'active';

  /// Check if buyer has unread messages
  bool get hasUnreadByBuyer => unreadByBuyer > 0;

  /// Check if tenant has unread messages
  bool get hasUnreadByTenant => unreadByTenant > 0;

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final typingRaw = json['typingUsers'] as Map<String, dynamic>?;
    final typingUsers = typingRaw != null
        ? Map<String, String>.fromEntries(
            typingRaw.entries.map((e) => MapEntry(e.key, e.value.toString())),
          )
        : const <String, String>{};

    return ChatModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      buyerUserId: json['buyerUserId'] as String? ?? '',
      orderId: json['orderId'] as String?,
      tenantName: json['tenantName'] as String?,
      buyerName: json['buyerName'] as String?,
      status: json['status'] as String? ?? 'active',
      lastMessage: json['lastMessage'] is Map<String, dynamic>
          ? LastMessage.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadByBuyer: json['unreadByBuyer'] as int? ?? 0,
      unreadByTenant: json['unreadByTenant'] as int? ?? 0,
      participants: () {
        final raw = json['participantIds'] ?? json['participants'];
        return raw is List<dynamic> ? raw.cast<String>() : <String>[];
      }(),
      createdAt: parseFirestoreDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updatedAt']) ?? DateTime.now(),
      typingUsers: typingUsers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'buyerUserId': buyerUserId,
      if (orderId != null) 'orderId': orderId,
      if (tenantName != null) 'tenantName': tenantName,
      if (buyerName != null) 'buyerName': buyerName,
      'status': status,
      if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
      'unreadByBuyer': unreadByBuyer,
      'unreadByTenant': unreadByTenant,
      'participantIds': participants,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (typingUsers.isNotEmpty) 'typingUsers': typingUsers,
    };
  }

  ChatModel copyWith({
    String? id,
    String? tenantId,
    String? buyerUserId,
    String? orderId,
    String? tenantName,
    String? buyerName,
    String? status,
    LastMessage? lastMessage,
    int? unreadByBuyer,
    int? unreadByTenant,
    List<String>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? typingUsers,
  }) {
    return ChatModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      buyerUserId: buyerUserId ?? this.buyerUserId,
      orderId: orderId ?? this.orderId,
      tenantName: tenantName ?? this.tenantName,
      buyerName: buyerName ?? this.buyerName,
      status: status ?? this.status,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadByBuyer: unreadByBuyer ?? this.unreadByBuyer,
      unreadByTenant: unreadByTenant ?? this.unreadByTenant,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class LastMessage {
  final String text;
  final DateTime sentAt;
  final String sentBy;
  final bool isFromBuyer;

  const LastMessage({
    required this.text,
    required this.sentAt,
    required this.sentBy,
    required this.isFromBuyer,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) {
    return LastMessage(
      text: json['text'] as String? ?? '',
      sentAt: parseFirestoreDate(json['sentAt']) ?? DateTime.now(),
      sentBy: json['sentBy'] as String? ?? '',
      isFromBuyer: json['isFromBuyer'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'sentAt': sentAt.toIso8601String(),
      'sentBy': sentBy,
      'isFromBuyer': isFromBuyer,
    };
  }
}
