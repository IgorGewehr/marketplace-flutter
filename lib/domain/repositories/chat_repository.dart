import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';

/// Chat Repository Interface
abstract class ChatRepository {
  /// Get list of chats
  Future<List<ChatModel>> getChats();

  /// Get chat by ID
  Future<ChatModel> getChatById(String chatId);

  /// Get chat by order ID
  Future<ChatModel?> getChatByOrderId(String orderId);

  /// Get messages for a chat
  Future<MessageListResponse> getMessages(
    String chatId, {
    int limit = 50,
    String? before, // message ID for pagination
  });

  /// Send a message
  Future<MessageModel> sendMessage({
    required String chatId,
    required String text,
    String type = 'text',
    String? imageUrl,
  });

  /// Send an image message
  Future<MessageModel> sendImageMessage({
    required String chatId,
    required String imagePath,
  });

  /// Mark messages as read
  Future<void> markAsRead(String chatId);

  /// Get total unread count
  Future<int> getUnreadCount();

  /// Start or get existing chat with seller
  Future<ChatModel> startChat({
    required String tenantId,
    String? orderId,
  });
}

/// Response wrapper for paginated message lists
class MessageListResponse {
  final List<MessageModel> messages;
  final bool hasMore;
  final String? oldestMessageId;

  const MessageListResponse({
    required this.messages,
    required this.hasMore,
    this.oldestMessageId,
  });

  factory MessageListResponse.fromJson(Map<String, dynamic> json) {
    return MessageListResponse(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      hasMore: json['hasMore'] as bool? ?? false,
      oldestMessageId: json['oldestMessageId'] as String?,
    );
  }
}
