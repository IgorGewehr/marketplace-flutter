import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/api_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Chat Repository Implementation
class ChatRepositoryImpl implements ChatRepository {
  final ApiClient _apiClient;

  ChatRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<ChatModel>> getChats() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.chats,
    );

    final chats = (response['chats'] as List<dynamic>?)
            ?.map((c) => ChatModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return chats;
  }

  @override
  Future<ChatModel> getChatById(String chatId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.chatById(chatId),
    );

    return ChatModel.fromJson(response);
  }

  @override
  Future<ChatModel?> getChatByOrderId(String orderId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.chats,
        queryParameters: {'orderId': orderId},
      );

      final chats = (response['chats'] as List<dynamic>?) ?? [];
      if (chats.isEmpty) return null;

      return ChatModel.fromJson(chats.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MessageListResponse> getMessages(
    String chatId, {
    int limit = 50,
    String? before,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.chatMessages(chatId),
      queryParameters: {
        'limit': limit,
        if (before != null) 'before': before,
      },
    );

    return MessageListResponse.fromJson(response);
  }

  @override
  Future<MessageModel> sendMessage({
    required String chatId,
    required String text,
    String type = 'text',
    String? imageUrl,
    String? replyToId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.chatMessages(chatId),
      data: {
        'type': type,
        if (type == 'text') 'text': text,
        if (type == 'image' && imageUrl != null) 'imageUrl': imageUrl,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );

    return MessageModel.fromJson(response);
  }

  @override
  Future<MessageModel> sendImageMessage({
    required String chatId,
    required String imagePath,
  }) async {
    final file = await MultipartFile.fromFile(imagePath);

    final response = await _apiClient.uploadFile<Map<String, dynamic>>(
      ApiConstants.chatMessages(chatId),
      files: [file],
      fileField: 'image',
      data: {'type': 'image'},
    );

    return MessageModel.fromJson(response);
  }

  @override
  Future<void> markAsRead(String chatId) async {
    await _apiClient.post<void>(
      '${ApiConstants.chatById(chatId)}/read',
    );
  }

  @override
  Future<int> getUnreadCount() async {
    final chats = await getChats();
    return chats.fold<int>(0, (sum, chat) => sum + chat.unreadByBuyer);
  }

  @override
  Future<ChatModel> startChat({
    required String tenantId,
    String? orderId,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.chats,
      data: {
        'tenantId': tenantId,
        if (orderId != null) 'orderId': orderId,
      },
    );

    return ChatModel.fromJson(response);
  }
}
