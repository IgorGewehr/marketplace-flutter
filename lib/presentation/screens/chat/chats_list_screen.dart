import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final unreadCount = ref.watch(unreadChatsCountProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 60,
        title: Row(
          children: [
            Text(
              'Conversas',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: AppSpacing.s),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar conversas...',
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textHint,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textHint,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
                  borderSide: BorderSide(
                    color: AppColors.border,
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 0.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
                  borderSide: BorderSide(
                    color: AppColors.primary.withAlpha(120),
                    width: 1.2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
      body: chatsAsync.when(
        loading: () =>
            const ShimmerLoading(itemCount: 5, isGrid: false, height: 72),
        error: (error, stack) => ErrorState(
          message: 'Erro ao carregar conversas',
          onRetry: () => ref.invalidate(chatsProvider),
        ),
        data: (chats) {
          // Filter chats by search query
          final filtered = _searchQuery.isEmpty
              ? chats
              : chats.where((c) {
                  final q = _searchQuery.toLowerCase();
                  return (c.tenantName?.toLowerCase().contains(q) ?? false) ||
                      (c.buyerName?.toLowerCase().contains(q) ?? false) ||
                      (c.lastMessage?.text.toLowerCase().contains(q) ?? false);
                }).toList();

          if (chats.isEmpty) {
            return const EmptyChatsState();
          }

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 56,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text(
                    'Nenhuma conversa encontrada',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(chatsProvider.notifier).refresh(),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final chat = filtered[index];
                final isBuyer = user?.id == chat.buyerUserId;
                final participant =
                    ref.watch(chatParticipantProvider(chat.id));

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
                )
                    .animate(delay: Duration(milliseconds: (index % 8) * 60))
                    .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
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
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXXL)),
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
