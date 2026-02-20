import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/message_model.dart';

/// Enhanced message input bar with reply preview and image attachment
class MessageInput extends StatefulWidget {
  final ValueChanged<String>? onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onImagePick;
  final bool isEnabled;
  final MessageModel? replyingTo;
  final String? replyingSenderName;
  final VoidCallback? onCancelReply;

  const MessageInput({
    super.key,
    this.onSend,
    this.onAttachment,
    this.onImagePick,
    this.isEnabled = true,
    this.replyingTo,
    this.replyingSenderName,
    this.onCancelReply,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.onSend != null) {
      widget.onSend!(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview bar
          if (widget.replyingTo != null) _buildReplyPreview(),
          // Input row
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.s,
              right: AppSpacing.s,
              top: AppSpacing.s,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.s,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment button
                IconButton(
                  onPressed: widget.isEnabled ? widget.onAttachment : null,
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: widget.isEnabled ? AppColors.textSecondary : AppColors.textHint,
                    size: 26,
                  ),
                ),
                // Text input
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: widget.isEnabled,
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSend(),
                            decoration: const InputDecoration(
                              hintText: 'Digite uma mensagem...',
                              hintStyle: TextStyle(color: AppColors.textHint),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.m,
                                vertical: 10,
                              ),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Camera quick access
                        if (!_hasText)
                          IconButton(
                            onPressed: widget.isEnabled ? widget.onImagePick : null,
                            icon: Icon(
                              Icons.camera_alt_outlined,
                              color: widget.isEnabled
                                  ? AppColors.textSecondary
                                  : AppColors.textHint,
                              size: 22,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Send button
                AnimatedContainer(
                  duration: AppSpacing.animNormal,
                  child: Material(
                    color: _hasText && widget.isEnabled
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
                    child: InkWell(
                      onTap: _hasText && widget.isEnabled ? _handleSend : null,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXXL),
                      child: Container(
                        width: AppSpacing.touchTarget,
                        height: AppSpacing.touchTarget,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.send_rounded,
                          color: _hasText && widget.isEnabled
                              ? Colors.white
                              : AppColors.textHint,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reply preview banner above the input
  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(8),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyingSenderName ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  widget.replyingTo?.content ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onCancelReply,
            icon: const Icon(Icons.close_rounded, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
