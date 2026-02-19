import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/chat/chat_tile.dart';
import '../../widgets/shared/error_state.dart';
import '../../widgets/shared/illustrated_empty_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Enhanced chat list screen with search and long-press actions
class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Conversas'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: chatsAsync.when(
        loading: () => const ShimmerLoading(itemCount: 5, isGrid: false, height: 72),
        error: (error, stack) => ErrorState(
          message: 'Erro ao carregar conversas',
          onRetry: () => ref.invalidate(chatsProvider),
        ),
        data: (chats) {
          if (chats.isEmpty) {
            return const EmptyChatsState();
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(chatsProvider.notifier).refresh(),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              itemCount: chats.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final chat = chats[index];
                final isBuyer = user?.id == chat.buyerUserId;
                final participant = ref.watch(chatParticipantProvider(chat.id));

                return ChatTile(
                  chat: chat,
                  participantName: participant?.name ?? 'Usuário',
                  participantAvatarUrl: participant?.avatarUrl,
                  isBuyer: isBuyer,
                  isOnline: participant?.isOnline ?? false,
                  onTap: () {
                    context.push(
                      AppRouter.chatDetails.replaceFirst(':id', chat.id),
                    );
                  },
                  onLongPress: () => _showChatActions(context, chat),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Long press actions
  void _showChatActions(BuildContext context, chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXXL)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            ListTile(
              leading: const Icon(Icons.mark_chat_read_outlined),
              title: const Text('Marcar como lida'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(chatsProvider.notifier).markChatAsRead(chat.id);
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }
}
