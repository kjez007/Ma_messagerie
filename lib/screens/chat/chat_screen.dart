import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:messagerie/models/conversation_model.dart';
import 'package:messagerie/models/message_model.dart';
import 'package:messagerie/models/user_model.dart';
import 'package:messagerie/services/chat_service.dart';
import 'package:messagerie/services/storage_service.dart';
import 'package:messagerie/widgets/message_bubble.dart';
import 'package:messagerie/widgets/user_avatar.dart';
import 'package:messagerie/utils/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  final UserModel currentUser;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.currentUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _storageService = StorageService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingMedia = false;
  RealtimeChannel? _realtimeChannel;

  late final String _conversationId;
  late final UserModel? _otherUser;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversation.id;
    _otherUser = widget.conversation.otherParticipant(widget.currentUser.id);
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getMessages(_conversationId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom(animated: false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _realtimeChannel = _chatService.subscribeToConversationUpdates(
      _conversationId,
      (newMessageData) async {
        // Éviter les doublons
        final exists = _messages.any((m) => m.id == newMessageData['id']);
        if (exists) return;

        // Recharger pour avoir le profil
        try {
          final messages = await _chatService.getMessages(_conversationId);
          if (mounted) {
            setState(() => _messages = messages);
            _scrollToBottom();
          }
        } catch (_) {}
      },
    );
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      }
    });
  }

  Future<void> _sendTextMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final message = await _chatService.sendTextMessage(
        conversationId: _conversationId,
        content: content,
      );

      if (mounted) {
        setState(() => _messages.add(message));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _messageController.text = content;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked == null) return;

      final file = File(picked.path);
      if (!_storageService.isFileSizeValid(file)) {
        _showSizeError(isVideo: false);
        return;
      }

      setState(() => _isUploadingMedia = true);

      final mediaUrl = await _storageService.uploadChatImage(file);
      final message = await _chatService.sendImageMessage(
        conversationId: _conversationId,
        mediaUrl: mediaUrl,
      );

      if (mounted) {
        setState(() => _messages.add(message));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;

      final file = File(filePath);
      if (!_storageService.isFileSizeValid(file, isVideo: true)) {
        _showSizeError(isVideo: true);
        return;
      }

      setState(() => _isUploadingMedia = true);

      final mediaUrl = await _storageService.uploadChatVideo(file);
      final message = await _chatService.sendVideoMessage(
        conversationId: _conversationId,
        mediaUrl: mediaUrl,
      );

      if (mounted) {
        setState(() => _messages.add(message));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vidéo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _showSizeError({required bool isVideo}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVideo
              ? 'Vidéo trop grande (max 50 MB)'
              : 'Image trop grande (max 10 MB)',
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MediaOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Caméra',
                  color: const Color(0xFF6C63FF),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                _MediaOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  color: const Color(0xFF03DAC6),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
                _MediaOption(
                  icon: Icons.videocam_rounded,
                  label: 'Vidéo',
                  color: const Color(0xFFFF6B9D),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendVideo();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.conversation
        .displayName(widget.currentUser.id);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            if (_otherUser != null) ...[
              UserAvatar(user: _otherUser!, size: 36),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_otherUser != null)
                    Text(
                      _otherUser!.isOnline ? '● En ligne' : 'Hors ligne',
                      style: TextStyle(
                        fontSize: 12,
                        color: _otherUser!.isOnline
                            ? AppTheme.online
                            : AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final message = _messages[i];
                          final isMe =
                              message.senderId == widget.currentUser.id;
                          final showAvatar = !isMe &&
                              (i == 0 ||
                                  _messages[i - 1].senderId !=
                                      message.senderId);
                          return MessageBubble(
                            message: message,
                            isMe: isMe,
                            showAvatar: showAvatar,
                            otherUser: _otherUser,
                          );
                        },
                      ),
          ),
          if (_isUploadingMedia) _buildUploadIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_otherUser != null)
            UserAvatar(user: _otherUser!, size: 64),
          const SizedBox(height: 16),
          Text(
            'Début de votre conversation\navec ${_otherUser?.username ?? 'cet utilisateur'}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.surface,
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Envoi du média en cours...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isUploadingMedia ? null : _showMediaPicker,
            icon: Icon(
              Icons.attach_file_rounded,
              color: _isUploadingMedia
                  ? AppTheme.textSecondary
                  : AppTheme.primary,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: AppTheme.textPrimary),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle:
                    const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendTextMessage(),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  onPressed: hasText && !_isSending ? _sendTextMessage : null,
                  icon: Icon(
                    Icons.send_rounded,
                    color: hasText
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MediaOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
