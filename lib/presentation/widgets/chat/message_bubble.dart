import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/message_model.dart';
import '../shared/app_feedback.dart';

/// Modern message bubble with swipe-to-reply, gradient, and polished styling
class MessageBubble extends StatefulWidget {
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
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _replyTriggered = false;
  late AnimationController _replyIconController;

  @override
  void initState() {
    super.initState();
    _replyIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _replyIconController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    // Received messages: swipe right. Sent messages: swipe left.
    if ((!widget.isMe && delta > 0) || (widget.isMe && delta < 0)) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(
          widget.isMe ? -60.0 : 0.0,
          widget.isMe ? 0.0 : 60.0,
        );
      });
      if (_dragOffset.abs() > 40 && !_replyTriggered) {
        _replyTriggered = true;
        _replyIconController.forward(from: 0);
        HapticFeedback.lightImpact();
      }
    }
  }

  void _handleDragEnd(DragEndDetails _) {
    if (_replyTriggered) widget.onReply?.call(widget.message);
    setState(() {
      _dragOffset = 0;
      _replyTriggered = false;
    });
    _replyIconController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showMessageActions(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Swipe-to-reply icon
          if (_dragOffset.abs() > 6)
            Positioned(
              left: widget.isMe ? null : 10,
              right: widget.isMe ? 10 : null,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.center,
                child: AnimatedBuilder(
                  animation: _replyIconController,
                  builder: (context, _) {
                    final progress = (_dragOffset.abs() / 60.0).clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: 0.4 + progress * 0.6,
                      child: Opacity(
                        opacity: progress,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(
                              _replyTriggered ? 40 : 20,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: _replyTriggered
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withAlpha(30),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.reply_rounded,
                            size: 18,
                            color: AppColors.primary.withAlpha(
                              _replyTriggered ? 255 : 180,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Bubble
          Transform.translate(
            offset: Offset(_dragOffset * 0.45, 0),
            child: Align(
              alignment:
                  widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                margin: EdgeInsets.only(
                  left: widget.isMe ? 52 : 16,
                  right: widget.isMe ? 16 : 52,
                  bottom: 3,
                ),
                child: Column(
                  crossAxisAlignment: widget.isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: widget.isMe
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.primary,
                                ],
                              )
                            : null,
                        color: widget.isMe ? null : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(
                              widget.isMe || !widget.showTail ? 18 : 5),
                          bottomRight: Radius.circular(
                              !widget.isMe || !widget.showTail ? 18 : 5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isMe
                                ? AppColors.primary.withAlpha(50)
                                : Colors.black.withAlpha(10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.message.hasReply) _buildReplyPreview(),
                          if (widget.message.text != null &&
                              _containsUrl(widget.message.text!))
                            _buildLinkPreview(widget.message.text!),
                          if (widget.message.isImage &&
                              widget.message.imageUrl != null)
                            _buildImageContent(),
                          if (widget.message.text != null &&
                              widget.message.text!.isNotEmpty) ...[
                            if (widget.message.isImage)
                              const SizedBox(height: AppSpacing.s),
                            Text(
                              widget.message.text!,
                              style: TextStyle(
                                fontSize: 15,
                                color: widget.isMe
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          _buildTimestamp(),
                        ],
                      ),
                    ),
                    if (widget.message.hasReactions) _buildReactionsRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _formatTime(widget.message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: widget.isMe
                ? Colors.white.withAlpha(170)
                : AppColors.textHint,
          ),
        ),
        if (widget.isMe) ...[
          const SizedBox(width: 3),
          Icon(
            widget.message.isRead
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14,
            color: widget.message.isRead
                ? Colors.white.withAlpha(230)
                : Colors.white.withAlpha(160),
          ),
        ],
      ],
    );
  }

  Widget _buildImageContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      child: CachedNetworkImage(
        imageUrl: widget.message.imageUrl!,
        width: 200,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        placeholder: (_, __) => Container(
          width: 200,
          height: 150,
          color: widget.isMe
              ? Colors.white.withAlpha(20)
              : AppColors.border,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.isMe ? Colors.white : AppColors.primary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 200,
          height: 150,
          color: AppColors.border,
          child: const Center(
            child: Icon(Icons.broken_image_outlined,
                color: AppColors.textHint),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withAlpha(22)
            : AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        border: Border(
          left: BorderSide(
            color: widget.isMe
                ? Colors.white.withAlpha(130)
                : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.replyToSenderName ?? '',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isMe
                  ? Colors.white.withAlpha(230)
                  : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyToText ?? '',
            style: TextStyle(
              fontSize: 12,
              color: widget.isMe
                  ? Colors.white.withAlpha(175)
                  : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPreview(String text) {
    final urlRegex = RegExp(r'https?://\S+');
    final match = urlRegex.firstMatch(text);
    if (match == null) return const SizedBox.shrink();

    final url = match.group(0)!;
    final uri = Uri.tryParse(url);
    final domain = uri?.host ?? url;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withAlpha(20)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        border: Border.all(
          color:
              widget.isMe ? Colors.white.withAlpha(40) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link_rounded,
            size: 16,
            color: widget.isMe
                ? Colors.white.withAlpha(180)
                : AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.s),
          Flexible(
            child: Text(
              domain,
              style: TextStyle(
                fontSize: 12,
                color: widget.isMe
                    ? Colors.white.withAlpha(200)
                    : AppColors.primary,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: widget.isMe
                    ? Colors.white.withAlpha(180)
                    : AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: widget.message.reactions.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          return GestureDetector(
            onTap: () => widget.onReact?.call(widget.message, emoji),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji,
                      style: const TextStyle(fontSize: 13)),
                  if (count > 1) ...[
                    const SizedBox(width: 3),
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
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.l),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
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
            _buildQuickReactions(ctx),
            const Divider(height: AppSpacing.l),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Responder'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onReply?.call(widget.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_rounded),
              title: const Text('Copiar texto'),
              onTap: () async {
                Navigator.pop(ctx);
                if (widget.message.text != null) {
                  await Clipboard.setData(
                      ClipboardData(text: widget.message.text!));
                  if (context.mounted) {
                    AppFeedback.showSuccess(context, 'Texto copiado');
                  }
                }
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReactions(BuildContext context) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '✅'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: emojis.map((emoji) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onReact?.call(widget.message, emoji);
          },
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        );
      }).toList(),
    );
  }

  bool _containsUrl(String text) =>
      RegExp(r'https?://\S+').hasMatch(text);

  String _formatTime(DateTime dateTime) =>
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

/// Date separator — label between horizontal dividers
class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.m, horizontal: AppSpacing.m),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.border, thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
                border:
                    Border.all(color: AppColors.border, width: 0.5),
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
          const Expanded(
            child: Divider(color: AppColors.border, thickness: 0.5),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return 'Hoje';
    if (messageDate == yesterday) return 'Ontem';
    return '${date.day}/${date.month}/${date.year}';
  }
}
