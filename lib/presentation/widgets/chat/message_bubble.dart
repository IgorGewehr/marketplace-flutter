import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/message_model.dart';

/// Enhanced message bubble with reply, reactions, and link preview
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showTail;
  final ValueChanged<MessageModel>? onReply;
  final void Function(MessageModel message, String emoji)? onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showTail = true,
    this.onReply,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageActions(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            left: isMe ? 48 : 16,
            right: isMe ? 16 : 48,
            bottom: 4,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe || !showTail ? 18 : 4),
                    bottomRight: Radius.circular(!isMe || !showTail ? 18 : 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply preview
                    if (message.hasReply) _buildReplyPreview(),
                    // Link preview
                    if (message.text != null && _containsUrl(message.text!))
                      _buildLinkPreview(message.text!),
                    // Message content
                    if (message.isImage && message.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                        child: Image.network(
                          message.imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 200,
                              height: 150,
                              color: AppColors.border,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    if (message.text != null && message.text!.isNotEmpty) ...[
                      if (message.isImage) const SizedBox(height: AppSpacing.s),
                      Text(
                        message.text!,
                        style: TextStyle(
                          fontSize: 15,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    // Timestamp and read status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? Colors.white.withAlpha(180)
                                : AppColors.textHint,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: message.isRead
                                ? AppColors.secondary
                                : Colors.white.withAlpha(180),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Reactions row
              if (message.hasReactions) _buildReactionsRow(),
            ],
          ),
        ),
      ),
    );
  }

  /// Reply preview bar inside the bubble
  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withAlpha(25)
            : AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white.withAlpha(120) : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToSenderName ?? '',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white.withAlpha(220) : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToText ?? '',
            style: TextStyle(
              fontSize: 12,
              color: isMe
                  ? Colors.white.withAlpha(180)
                  : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Simple link preview detection
  Widget _buildLinkPreview(String text) {
    final urlRegex = RegExp(r'https?://\S+');
    final match = urlRegex.firstMatch(text);
    if (match == null) return const SizedBox.shrink();

    final url = match.group(0)!;
    // Extract domain for display
    final uri = Uri.tryParse(url);
    final domain = uri?.host ?? url;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withAlpha(20)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        border: Border.all(
          color: isMe
              ? Colors.white.withAlpha(40)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link_rounded,
            size: 16,
            color: isMe ? Colors.white.withAlpha(180) : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.s),
          Flexible(
            child: Text(
              domain,
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white.withAlpha(200) : AppColors.primary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Reactions display below the bubble
  Widget _buildReactionsRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 4,
        children: message.reactions.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                if (count > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Long-press message actions: reply, react, copy
  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXXL),
          ),
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
            // Quick reactions row
            _buildQuickReactions(ctx),
            const Divider(height: AppSpacing.l),
            // Actions
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Responder'),
              onTap: () {
                Navigator.pop(ctx);
                onReply?.call(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_rounded),
              title: const Text('Copiar texto'),
              onTap: () {
                Navigator.pop(ctx);
                if (message.text != null) {
                  // ignore: unused_import
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    const SnackBar(content: Text('Texto copiado')),
                  );
                }
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Quick reaction emoji row
  Widget _buildQuickReactions(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '✅'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: emojis.map((emoji) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            onReact?.call(message, emoji);
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }

  bool _containsUrl(String text) {
    return RegExp(r'https?://\S+').hasMatch(text);
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Date separator for grouping messages by day
class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          ),
          child: Text(
            _formatDate(date),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Hoje';
    } else if (messageDate == yesterday) {
      return 'Ontem';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
