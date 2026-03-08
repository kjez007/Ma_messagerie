import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:messagerie/models/message_model.dart';
import 'package:messagerie/models/user_model.dart';
import 'package:messagerie/screens/chat/media_viewer_screen.dart';
import 'package:messagerie/widgets/user_avatar.dart';
import 'package:messagerie/utils/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final UserModel? otherUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = false,
    this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar && otherUser != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: UserAvatar(user: otherUser!, size: 28),
              )
            else
              const SizedBox(width: 34),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildBubble(context),
                const SizedBox(height: 2),
                _buildMeta(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final color =
        isMe ? AppTheme.bubbleSent : AppTheme.bubbleReceived;

    return GestureDetector(
      onLongPress: isMe ? () => _showDeleteDialog(context) : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68,
        ),
        decoration: BoxDecoration(
          color: message.isText ? color : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          child: switch (message.type) {
            MessageType.text => _buildTextContent(),
            MessageType.image => _buildImageContent(context),
            MessageType.video => _buildVideoContent(context),
          },
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        message.content ?? '',
        style: TextStyle(
          color: isMe ? Colors.white : AppTheme.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            mediaUrl: message.mediaUrl!,
            isVideo: false,
            senderName: message.senderName,
          ),
        ),
      ),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            width: 240,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 240,
              height: 200,
              color: AppTheme.surfaceVariant,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 240,
              height: 200,
              color: AppTheme.surfaceVariant,
              child: const Icon(
                Icons.broken_image_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.zoom_out_map_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            mediaUrl: message.mediaUrl!,
            isVideo: true,
            senderName: message.senderName,
          ),
        ),
      ),
      child: Container(
        width: 240,
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (message.thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: message.thumbnailUrl!,
                width: 240,
                height: 160,
                fit: BoxFit.cover,
              ),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            if (message.mediaDuration != null)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(message.mediaDuration!),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded,
                        color: Colors.white, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Vidéo',
                      style:
                          TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta() {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14,
            color: message.isRead
                ? AppTheme.primary
                : AppTheme.textSecondary,
          ),
        ],
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Supprimer le message',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Voulez-vous supprimer ce message ?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Appeler le service de suppression
            },
            child: const Text('Supprimer',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
