/// Message model for chat messages
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String type; // text, image
  final String? text;
  final String? imageUrl;
  final String sentBy;
  final bool isFromBuyer;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Reply support
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;
  // Reactions support
  final Map<String, List<String>> reactions; // emoji -> list of userIds

  const MessageModel({
    required this.id,
    required this.chatId,
    this.type = 'text',
    this.text,
    this.imageUrl,
    required this.sentBy,
    required this.isFromBuyer,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
    this.reactions = const {},
  });

  /// Check if message is read
  bool get isRead => readAt != null;

  /// Check if message is text type
  bool get isText => type == 'text';

  /// Check if message is image type
  bool get isImage => type == 'image';

  /// Get message content (text or image indicator)
  String get content => text ?? (isImage ? '[Imagem]' : '');

  /// Check if message has a reply reference
  bool get hasReply => replyToId != null;

  /// Check if message has reactions
  bool get hasReactions => reactions.isNotEmpty;

  /// Create from Firestore document snapshot (handles Timestamp objects)
  factory MessageModel.fromFirestore(Map<String, dynamic> json) {
    final reactionsJson = json['reactions'] as Map<String, dynamic>?;
    final reactions = <String, List<String>>{};
    if (reactionsJson != null) {
      for (final entry in reactionsJson.entries) {
        reactions[entry.key] = (entry.value as List<dynamic>).cast<String>();
      }
    }

    return MessageModel(
      id: json['id'] as String? ?? '',
      chatId: json['chatId'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sentBy: json['sentBy'] as String? ?? '',
      isFromBuyer: json['isFromBuyer'] as bool? ?? false,
      readAt: _parseTimestamp(json['readAt']),
      createdAt: _parseTimestamp(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(json['updatedAt']) ?? DateTime.now(),
      replyToId: json['replyToId'] as String?,
      replyToText: json['replyToText'] as String?,
      replyToSenderName: json['replyToSenderName'] as String?,
      reactions: reactions,
    );
  }

  /// Parse a value that could be a Firestore Timestamp, ISO string, or null
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Parse reactions map
    final reactionsJson = json['reactions'] as Map<String, dynamic>?;
    final reactions = <String, List<String>>{};
    if (reactionsJson != null) {
      for (final entry in reactionsJson.entries) {
        reactions[entry.key] = (entry.value as List<dynamic>).cast<String>();
      }
    }

    return MessageModel(
      id: json['id'] as String? ?? '',
      chatId: json['chatId'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sentBy: json['sentBy'] as String? ?? '',
      isFromBuyer: json['isFromBuyer'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      replyToId: json['replyToId'] as String?,
      replyToText: json['replyToText'] as String?,
      replyToSenderName: json['replyToSenderName'] as String?,
      reactions: reactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'type': type,
      if (text != null) 'text': text,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'sentBy': sentBy,
      'isFromBuyer': isFromBuyer,
      if (readAt != null) 'readAt': readAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      if (reactions.isNotEmpty) 'reactions': reactions,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? type,
    String? text,
    String? imageUrl,
    String? sentBy,
    bool? isFromBuyer,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? replyToId,
    String? replyToText,
    String? replyToSenderName,
    Map<String, List<String>>? reactions,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      sentBy: sentBy ?? this.sentBy,
      isFromBuyer: isFromBuyer ?? this.isFromBuyer,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
