import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../data/services/image_upload_service.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'tenant_provider.dart';

/// Chat provider for managing conversations
class ChatsNotifier extends AsyncNotifier<List<ChatModel>> {
  StreamSubscription<QuerySnapshot>? _chatsSubscription;

  @override
  Future<List<ChatModel>> build() async {
    // ref.watch ensures this rebuilds (and disposes the old listener) on auth change.
    // This is critical: without it, a stale Firestore listener from a previous user
    // session would continue streaming that user's chats to the newly signed-in user.
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return [];

    // Set up real-time listener for chat list
    _setupRealtimeListener(user.id);

    // Clean up on dispose
    ref.onDispose(() {
      _chatsSubscription?.cancel();
    });

    // Initial fetch via REST (faster first load)
    return _fetchChats();
  }

  void _setupRealtimeListener(String userId) {
    _chatsSubscription?.cancel();
    _chatsSubscription = FirebaseFirestore.instance
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        final chats = snapshot.docs.map((doc) {
          final data = doc.data();
          return ChatModel.fromJson(_serializeFirestoreData(data));
        }).toList();
        state = AsyncValue.data(chats);
      },
      onError: (_) {
        // Silent fail - we still have the REST data
      },
    );
  }

  Future<List<ChatModel>> _fetchChats() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      return await repo.getChats();
    } catch (e) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchChats());
  }

  Future<ChatModel?> getOrCreateChat(String tenantId, {String? orderId}) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return null;

    // Check if chat exists locally
    final chats = state.valueOrNull ?? [];
    final existing = chats.where((c) =>
      c.tenantId == tenantId &&
      ((orderId == null && c.orderId == null) || c.orderId == orderId)
    ).firstOrNull;

    if (existing != null) return existing;

    try {
      // Create via API (backend handles notifications, participant setup)
      final repo = ref.read(chatRepositoryProvider);
      final chat = await repo.startChat(tenantId: tenantId, orderId: orderId);
      state = AsyncValue.data([chat, ...chats]);
      return chat;
    } catch (e) {
      return null;
    }
  }

  Future<void> markChatAsRead(String chatId) async {
    final chats = state.valueOrNull ?? [];
    final index = chats.indexWhere((c) => c.id == chatId);
    if (index == -1) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    final isBuyer = user?.id == chats[index].buyerUserId;

    // Optimistic local update
    final updated = chats[index].copyWith(
      unreadByBuyer: isBuyer ? 0 : chats[index].unreadByBuyer,
      unreadByTenant: isBuyer ? chats[index].unreadByTenant : 0,
    );

    final newList = [...chats];
    newList[index] = updated;
    state = AsyncValue.data(newList);

    // Persist to backend
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.markAsRead(chatId);
    } catch (_) {
      // Silent fail - local state is already updated
    }
  }
}

final chatsProvider = AsyncNotifierProvider<ChatsNotifier, List<ChatModel>>(
  () => ChatsNotifier(),
);

/// Total unread chats count for badge
final unreadChatsCountProvider = Provider<int>((ref) {
  final chats = ref.watch(chatsProvider).valueOrNull ?? [];
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return 0;

  return chats.fold(0, (sum, chat) {
    final isBuyer = user.id == chat.buyerUserId;
    return sum + (isBuyer ? chat.unreadByBuyer : chat.unreadByTenant);
  });
});

/// Real-time messages provider using Firestore snapshots
/// Reads from Firestore directly for instant updates, sends via REST API
class ChatMessagesNotifier extends FamilyAsyncNotifier<List<MessageModel>, String> {
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  Future<List<MessageModel>> build(String chatId) async {
    // Set up real-time listener
    _setupRealtimeListener(chatId);

    // Clean up on dispose
    ref.onDispose(() {
      _messagesSubscription?.cancel();
    });

    // Return empty list initially - real-time listener will populate
    return [];
  }

  void _setupRealtimeListener(String chatId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
        .snapshots()
        .listen(
      (snapshot) {
        final messages = snapshot.docs.map((doc) {
          return MessageModel.fromFirestore(doc.data());
        }).toList();
        state = AsyncValue.data(messages);
      },
      onError: (error) {
        // Fallback to REST if Firestore listener fails
        _fetchMessagesViaRest(chatId);
      },
    );
  }

  Future<void> _fetchMessagesViaRest(String chatId) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final response = await repo.getMessages(chatId);
      state = AsyncValue.data(response.messages);
    } catch (e) {
      state = AsyncValue.data([]);
    }
  }

  Future<void> refresh() async {
    // Re-establish the listener
    _setupRealtimeListener(arg);
  }

  /// Send a text message via REST API (backend handles notifications, unread counts)
  Future<MessageModel?> sendMessage(String text, {String? replyToId}) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return null;

    final chats = ref.read(chatsProvider).valueOrNull ?? [];
    final chat = chats.where((c) => c.id == arg).firstOrNull;
    if (chat == null) return null;

    final isBuyer = user.id == chat.buyerUserId;

    // Create optimistic message (will be replaced by Firestore snapshot)
    final message = MessageModel(
      id: const Uuid().v4(),
      chatId: arg,
      text: text,
      sentBy: user.id,
      isFromBuyer: isBuyer,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Add optimistically (Firestore listener will reconcile)
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, message]);

    // Send via REST API (handles notifications, unread counts, push)
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.sendMessage(chatId: arg, text: text, replyToId: replyToId)
          .timeout(const Duration(seconds: 30));

      // Remove optimistic message - Firestore listener will add the real one
      final msgs = state.valueOrNull ?? [];
      state = AsyncValue.data(
        msgs.where((m) => m.id != message.id).toList(),
      );
    } catch (_) {
      // Remove failed optimistic message so it doesn't ghost
      final msgs = state.valueOrNull ?? [];
      state = AsyncValue.data(
        msgs.where((m) => m.id != message.id).toList(),
      );
      rethrow;
    }

    return message;
  }

  /// Send an image message: upload to Storage, then send via REST API
  Future<MessageModel?> sendImageMessage(File imageFile) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return null;

    final chats = ref.read(chatsProvider).valueOrNull ?? [];
    final chat = chats.where((c) => c.id == arg).firstOrNull;
    if (chat == null) return null;

    final isBuyer = user.id == chat.buyerUserId;

    // Create optimistic placeholder message
    final optimisticId = const Uuid().v4();
    final placeholder = MessageModel(
      id: optimisticId,
      chatId: arg,
      type: 'image',
      text: null,
      sentBy: user.id,
      isFromBuyer: isBuyer,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, placeholder]);

    try {
      // Upload image to Firebase Storage
      final imageUrl = await imageUploadServiceProvider.uploadChatImage(
        imageFile,
        arg,
      );

      // Send via REST API with imageUrl
      final repo = ref.read(chatRepositoryProvider);
      await repo.sendMessage(
        chatId: arg,
        text: imageUrl,
        type: 'image',
        imageUrl: imageUrl,
      );

      // Firestore listener will replace the optimistic message
      return placeholder;
    } catch (e) {
      // Remove failed optimistic message
      final msgs = state.valueOrNull ?? [];
      state = AsyncValue.data(
        msgs.where((m) => m.id != optimisticId).toList(),
      );
      rethrow;
    }
  }

  /// Toggle a reaction on a message via Firestore
  Future<void> toggleReaction(String messageId, String emoji) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(arg)
        .collection('messages')
        .doc(messageId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
        final userIds = List<String>.from(reactions[emoji] ?? []);

        if (userIds.contains(user.id)) {
          userIds.remove(user.id);
        } else {
          userIds.add(user.id);
        }

        if (userIds.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = userIds;
        }

        tx.update(docRef, {'reactions': reactions});
      });
    } catch (_) {
      // Silent fail - Firestore listener will sync state
    }
  }

  Future<void> markAsRead() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    // Update chat unread count locally + backend
    ref.read(chatsProvider.notifier).markChatAsRead(arg);
  }

  Future<void> updateTypingStatus(bool isTyping) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.updateTypingStatus(arg, user.id, isTyping);
    } catch (e) {
      debugPrint('Typing status update failed: $e');
    }
  }
}

final chatMessagesProvider = AsyncNotifierProvider.family<ChatMessagesNotifier, List<MessageModel>, String>(
  () => ChatMessagesNotifier(),
);

/// Returns true if the other participant is currently typing (last-typed < 10s ago)
final isOtherUserTypingProvider = Provider.family<bool, String>((ref, chatId) {
  final chats = ref.watch(chatsProvider).valueOrNull ?? [];
  final chat = chats.where((c) => c.id == chatId).firstOrNull;
  if (chat == null) return false;

  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;

  final typingUsers = chat.typingUsers;
  if (typingUsers.isEmpty) return false;

  final now = DateTime.now();
  for (final entry in typingUsers.entries) {
    if (entry.key == user.id) continue;
    final lastTyped = DateTime.tryParse(entry.value);
    if (lastTyped != null && now.difference(lastTyped).inSeconds < 10) {
      return true;
    }
  }
  return false;
});

/// Chat participant info for display
class ChatParticipant {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool isOnline;

  const ChatParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isOnline = false,
  });
}

/// Get other participant info for a chat.
/// For buyers: resolves tenant → ownerUserId → user to show the seller's
/// real name (displayName) and photo (photoURL) in header and chat list.
final chatParticipantProvider = Provider.family<ChatParticipant?, String>((ref, chatId) {
  final chats = ref.watch(chatsProvider).valueOrNull ?? [];
  final chat = chats.where((c) => c.id == chatId).firstOrNull;
  if (chat == null) return null;

  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;

  final isBuyer = user.id == chat.buyerUserId;

  if (isBuyer) {
    // Step 1: fetch tenant to get ownerUserId
    final tenantAsync = ref.watch(tenantByIdProvider(chat.tenantId));
    final tenant = tenantAsync.valueOrNull;

    // Step 2: fetch owner user for real displayName + photoURL
    final ownerUserId = tenant?.ownerUserId ?? '';
    final ownerUserAsync = ownerUserId.isNotEmpty
        ? ref.watch(userByIdProvider(ownerUserId))
        : null;
    final ownerUser = ownerUserAsync?.valueOrNull;

    // Name priority: owner user > tenant display name > stored chat name > fallback
    final name = ownerUser?.displayName.isNotEmpty == true
        ? ownerUser!.displayName
        : tenant?.displayName.isNotEmpty == true
            ? tenant!.displayName
            : chat.tenantName?.trim().isNotEmpty == true
                ? chat.tenantName!
                : 'Vendedor';

    return ChatParticipant(
      id: chat.tenantId,
      name: name,
      avatarUrl: ownerUser?.photoURL ?? tenant?.logoURL,
    );
  } else {
    final name = (chat.buyerName?.trim().isNotEmpty == true) ? chat.buyerName! : 'Comprador';
    return ChatParticipant(
      id: chat.buyerUserId,
      name: name,
    );
  }
});

/// Helper to serialize Firestore data (Timestamps -> ISO strings)
/// Handles nested Maps and Lists recursively
Map<String, dynamic> _serializeFirestoreData(Map<String, dynamic> data) {
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    result[entry.key] = _serializeValue(entry.value);
  }
  return result;
}

dynamic _serializeValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  } else if (value is Map<String, dynamic>) {
    return _serializeFirestoreData(value);
  } else if (value is Map) {
    return _serializeFirestoreData(Map<String, dynamic>.from(value));
  } else if (value is List) {
    return value.map(_serializeValue).toList();
  }
  return value;
}
