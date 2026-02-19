import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/chat_model.dart';

/// Enhanced chat tile with larger avatars, name-derived colors, and online indicator
class ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String participantName;
  final String? participantAvatarUrl;
  final bool isBuyer;
  final bool isOnline;
  final bool isPinned;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatTile({
    super.key,
    required this.chat,
    required this.participantName,
    this.participantAvatarUrl,
    required this.isBuyer,
    this.isOnline = false,
    this.isPinned = false,
    this.onTap,
    this.onLongPress,
  });

  int get unreadCount => isBuyer ? chat.unreadByBuyer : chat.unreadByTenant;
  bool get hasUnread => unreadCount > 0;

  /// Generate a consistent color from a name for avatar backgrounds
  Color _getAvatarColor(String name) {
    if (name.isEmpty) return AppColors.textHint;
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    const colors = [
      Color(0xFF2196F3), // Blue
      Color(0xFF00BCD4), // Cyan
      Color(0xFF009688), // Teal
      Color(0xFF4CAF50), // Green
      Color(0xFFFF9800), // Orange
      Color(0xFFE91E63), // Pink
      Color(0xFF9C27B0), // Purple
      Color(0xFF673AB7), // Deep Purple
      Color(0xFF3F51B5), // Indigo
      Color(0xFFFF5722), // Deep Orange
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _getAvatarColor(participantName);

    return Material(
      color: hasUnread ? AppColors.primary.withAlpha(10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Avatar with online indicator (44px)
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: participantAvatarUrl != null
                        ? AppColors.border
                        : avatarColor,
                    backgroundImage: participantAvatarUrl != null
                        ? NetworkImage(participantAvatarUrl!)
                        : null,
                    child: participantAvatarUrl == null
                        ? Text(
                            participantName.isNotEmpty
                                ? participantName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  // Online indicator
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasUnread
                                ? AppColors.primary.withAlpha(10)
                                : Colors.white,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  // Unread badge
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Pinned icon
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: AppColors.textHint,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            participantName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Text(
                          _formatTimestamp(chat.lastMessage?.sentAt ?? chat.updatedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread ? AppColors.primary : AppColors.textHint,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        // Check mark for sent messages
                        if (chat.lastMessage != null &&
                            chat.lastMessage!.isFromBuyer == isBuyer)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: Icon(
                              Icons.done_all,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                          ),
                        // Order badge if chat is linked to an order
                        if (chat.orderId != null)
                          Container(
                            margin: const EdgeInsets.only(right: AppSpacing.xs),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                            ),
                            child: const Text(
                              'Pedido',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            chat.lastMessage?.text ?? 'Sem mensagens',
                            style: TextStyle(
                              fontSize: 14,
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'agora';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}min';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else if (diff.inDays == 1) {
      return 'ontem';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
