import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/message_model.dart';

/// Modern message input bar with smooth animations and polished styling
class MessageInput extends StatefulWidget {
  final ValueChanged<String>? onSend;
  final VoidCallback? onAttachment;
  final VoidCallback? onImagePick;
  final bool isEnabled;
  final MessageModel? replyingTo;
  final String? replyingSenderName;
  final VoidCallback? onCancelReply;
  final ValueChanged<bool>? onTyping;

  const MessageInput({
    super.key,
    this.onSend,
    this.onAttachment,
    this.onImagePick,
    this.isEnabled = true,
    this.replyingTo,
    this.replyingSenderName,
    this.onCancelReply,
    this.onTyping,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;

  @override
  void initState() {
    super.initState();
    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sendButtonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _sendButtonController, curve: Curves.elasticOut),
    );
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
        if (hasText) {
          _sendButtonController.forward();
        } else {
          _sendButtonController.reverse();
        }
      }
      _handleTypingChange();
    });
  }

  void _handleTypingChange() {
    if (!_isTyping) {
      _isTyping = true;
      widget.onTyping?.call(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        widget.onTyping?.call(false);
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_isTyping) widget.onTyping?.call(false);
    _controller.dispose();
    _focusNode.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.onSend != null) {
      HapticFeedback.lightImpact();
      widget.onSend!(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview — animated slide in/out
          AnimatedSize(
            duration: AppSpacing.animNormal,
            curve: Curves.easeOut,
            child: widget.replyingTo != null
                ? _buildReplyPreview()
                : const SizedBox.shrink(),
          ),
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
                _buildIconButton(
                  icon: Icons.add_circle_outline_rounded,
                  onTap: widget.isEnabled ? widget.onAttachment : null,
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.xs),
                // Text input field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusXXL),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? AppColors.primary.withAlpha(80)
                            : AppColors.border,
                        width: 1,
                      ),
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
                            maxLength: 5000,
                            maxLengthEnforcement:
                                MaxLengthEnforcement.enforced,
                            textCapitalization:
                                TextCapitalization.sentences,
                            textInputAction: TextInputAction.newline,
                            onSubmitted: (_) => _handleSend(),
                            buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) {
                              if (currentLength < 4500) return null;
                              return Text(
                                '$currentLength/$maxLength',
                                style: TextStyle(
                                  color: currentLength > 4900
                                      ? Colors.red
                                      : AppColors.textHint,
                                  fontSize: 11,
                                ),
                              );
                            },
                            decoration: const InputDecoration(
                              hintText: 'Digite uma mensagem...',
                              hintStyle: TextStyle(
                                  color: AppColors.textHint, fontSize: 15),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        // Camera quick access (shown only when no text)
                        AnimatedSwitcher(
                          duration: AppSpacing.animNormal,
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                  scale: animation, child: child),
                          child: !_hasText
                              ? _buildIconButton(
                                  key: const ValueKey('camera'),
                                  icon: Icons.camera_alt_outlined,
                                  onTap: widget.isEnabled
                                      ? widget.onImagePick
                                      : null,
                                  size: 22,
                                  padding: const EdgeInsets.fromLTRB(
                                      0, 0, 6, 4),
                                )
                              : const SizedBox(
                                  key: ValueKey('empty'), width: 4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                // Send button — scales in when text is present
                _buildSendButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    Key? key,
    required IconData icon,
    VoidCallback? onTap,
    double size = 24,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Padding(
          padding: padding,
          child: Icon(
            icon,
            color: onTap != null
                ? AppColors.textSecondary
                : AppColors.textHint,
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _hasText && widget.isEnabled ? _handleSend : null,
      child: AnimatedContainer(
        duration: AppSpacing.animNormal,
        curve: Curves.easeOut,
        width: AppSpacing.touchTarget,
        height: AppSpacing.touchTarget,
        decoration: BoxDecoration(
          gradient: _hasText && widget.isEnabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primary],
                )
              : null,
          color: _hasText && widget.isEnabled ? null : AppColors.border,
          shape: BoxShape.circle,
          boxShadow: _hasText && widget.isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: AnimatedSwitcher(
          duration: AppSpacing.animFast,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            Icons.send_rounded,
            key: ValueKey(_hasText),
            color: _hasText && widget.isEnabled
                ? Colors.white
                : AppColors.textHint,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m, vertical: AppSpacing.s),
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
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
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
                const SizedBox(height: 2),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onCancelReply,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
