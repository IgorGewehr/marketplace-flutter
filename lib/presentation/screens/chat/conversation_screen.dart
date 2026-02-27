import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/message_input.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/error_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Enhanced conversation screen with order context, reply, and image support
class ConversationScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ConversationScreen({super.key, required this.chatId});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scrollController = ScrollController();
  MessageModel? _replyingTo;
  String? _replyingSenderName;
  bool _isUploadingImage = false;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read after short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(chatMessagesProvider(widget.chatId).notifier).markAsRead();
      }
    });
    _scrollController.addListener(() {
      final isNearBottom = _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent -
                  _scrollController.offset >
              300;
      if (isNearBottom != _showScrollToBottom) {
        setState(() => _showScrollToBottom = isNearBottom);
      }
    });
  }

  @override
  void dispose() {
    try {
      ref.read(chatMessagesProvider(widget.chatId).notifier).updateTypingStatus(false);
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setReplyTo(MessageModel message) {
    final user = ref.read(currentUserProvider).valueOrNull;
    final participant = ref.read(chatParticipantProvider(widget.chatId));
    final isMe = message.sentBy == user?.id;

    setState(() {
      _replyingTo = message;
      _replyingSenderName = isMe ? 'Você' : (participant?.name ?? 'Usuário');
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingSenderName = null;
    });
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return AppColors.textHint;
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    const colors = [
      Color(0xFF43A047),
      Color(0xFF00BCD4),
      Color(0xFF009688),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF673AB7),
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final participant = ref.watch(chatParticipantProvider(widget.chatId));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final chats = ref.watch(chatsProvider).valueOrNull ?? [];
    final chat = chats.where((c) => c.id == widget.chatId).firstOrNull;
    final isOtherTyping = ref.watch(isOtherUserTypingProvider(widget.chatId));

    // Scroll to bottom when new messages arrive
    ref.listen(chatMessagesProvider(widget.chatId), (prev, next) {
      final prevCount = prev?.valueOrNull?.length ?? 0;
      final nextCount = next.valueOrNull?.length ?? 0;
      if (nextCount > prevCount) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    final avatarColor = _getAvatarColor(participant?.name ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFECF0F5),
      floatingActionButton: _showScrollToBottom
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
        title: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: participant?.avatarUrl != null
                      ? AppColors.border
                      : avatarColor,
                  backgroundImage: participant?.avatarUrl != null
                      ? NetworkImage(participant!.avatarUrl!)
                      : null,
                  child: participant?.avatarUrl == null
                      ? Text(
                          participant?.name.isNotEmpty == true
                              ? participant!.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (participant?.isOnline == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant?.name ?? 'Usuário',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (participant?.isOnline == true)
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showChatOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Order context card
          if (chat?.orderId != null) _buildOrderContextCard(chat!),
          // Messages
          Expanded(
            child: messagesAsync.when(
              loading: () => const ShimmerLoading(itemCount: 6, isGrid: false),
              error: (error, stack) => ErrorState(
                message: 'Erro ao carregar mensagens',
                onRetry: () => ref.invalidate(chatMessagesProvider(widget.chatId)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        const Text(
                          'Nenhuma mensagem ainda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Diga olá! 👋',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.sentBy == user?.id;

                    // Check if we should show date separator
                    final showDateSeparator = index == 0 ||
                        !_isSameDay(messages[index - 1].createdAt, message.createdAt);

                    // Check if next message is from same sender (for bubble tail)
                    final showTail = index == messages.length - 1 ||
                        messages[index + 1].sentBy != message.sentBy ||
                        !_isSameDay(message.createdAt, messages[index + 1].createdAt);

                    return Column(
                      children: [
                        if (showDateSeparator)
                          DateSeparator(date: message.createdAt),
                        MessageBubble(
                          message: message,
                          isMe: isMe,
                          showTail: showTail,
                          onReply: _setReplyTo,
                          onReact: (msg, emoji) {
                            ref.read(chatMessagesProvider(widget.chatId).notifier)
                                .toggleReaction(msg.id, emoji);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Typing indicator
          if (isOtherTyping)
            TypingIndicator(name: participant?.name),
          // Image upload progress indicator
          if (_isUploadingImage)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          // Message input
          MessageInput(
            onSend: (text) async {
              try {
                await ref.read(chatMessagesProvider(widget.chatId).notifier)
                    .sendMessage(text, replyToId: _replyingTo?.id);
              } catch (e) {
                if (mounted) {
                  AppFeedback.showError(context, 'Falha ao enviar mensagem. Tente novamente.');
                }
              }
              _cancelReply();
            },
            onAttachment: () => _showAttachmentOptions(context),
            onImagePick: () => _pickImage(context),
            isEnabled: !_isUploadingImage,
            replyingTo: _replyingTo,
            replyingSenderName: _replyingSenderName,
            onCancelReply: _cancelReply,
            onTyping: (isTyping) {
              ref.read(chatMessagesProvider(widget.chatId).notifier)
                  .updateTypingStatus(isTyping);
            },
          ),
        ],
      ),
    );
  }

  /// Order context card pinned at the top of the conversation
  Widget _buildOrderContextCard(ChatModel chat) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: () {
          context.push(
            AppRouter.orderDetails.replaceFirst(':id', chat.orderId!),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border.withAlpha(60)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conversa sobre pedido',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Pedido #${chat.orderId!.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick image from gallery and send
  Future<void> _pickImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        await _sendImage(File(image.path));
      }
    } on PlatformException {
      if (mounted) {
        AppFeedback.showWarning(context, 'Permissão de acesso à galeria necessária');
      }
    }
  }

  /// Upload and send image message
  Future<void> _sendImage(File imageFile) async {
    setState(() => _isUploadingImage = true);
    try {
      await ref.read(chatMessagesProvider(widget.chatId).notifier)
          .sendImageMessage(imageFile);
    } catch (e) {
      if (mounted) {
        // Gap #21: Friendly error message
        AppFeedback.showError(context, 'Erro ao enviar imagem. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showChatOptions(BuildContext context) {
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
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Atualizar conversa'),
              onTap: () {
                Navigator.pop(ctx);
                ref.invalidate(chatMessagesProvider(widget.chatId));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.error),
              title: const Text('Denunciar', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                if (context.mounted) {
                  _showReportDialog(context);
                }
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    String? selectedReason;
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Denunciar conversa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Motivo da denúncia:'),
              const SizedBox(height: 8),
              ...['Conteúdo inapropriado', 'Spam', 'Assédio', 'Outro']
                  .map((reason) => RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) => setDialogState(() => selectedReason = v),
                      )),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                maxLength: 200,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalhes (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selectedReason == null
                  ? null
                  : () => Navigator.pop(dialogCtx, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedReason == null) return;
    if (!mounted) return;

    try {
      await ref.read(chatRepositoryProvider).reportChat(
            widget.chatId,
            selectedReason!,
            details: detailsController.text.trim(),
          );
      if (mounted) {
        AppFeedback.showSuccess(context, 'Denúncia enviada. Nossa equipe irá analisar.');
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showError(context, 'Erro ao enviar denúncia. Tente novamente.');
      }
    } finally {
      detailsController.dispose();
    }
  }

  void _showAttachmentOptions(BuildContext context) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeria',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(context);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Câmera',
                  color: AppColors.secondary,
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1200,
                        maxHeight: 1200,
                        imageQuality: 85,
                      );
                      if (image != null && mounted) {
                        await _sendImage(File(image.path));
                      }
                    } on PlatformException {
                      if (mounted) {
                        AppFeedback.showWarning(context, 'Permissão de câmera necessária');
                      }
                    }
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Documento',
                  color: AppColors.sellerAccent,
                  onTap: () {
                    Navigator.pop(ctx);
                    AppFeedback.showInfo(context, 'Envio de documentos em breve');
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
