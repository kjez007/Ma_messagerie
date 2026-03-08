import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:messagerie/models/conversation_model.dart';
import 'package:messagerie/models/user_model.dart';
import 'package:messagerie/utils/app_theme.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = conversation.otherParticipant(currentUserId);
    final displayName = conversation.displayName(currentUserId);
    final lastMsg = conversation.lastMessage;
    final unread = conversation.unreadCount;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildAvatar(otherUser),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMsg != null)
                        Text(
                          timeago.format(
                            lastMsg.createdAt.toLocal(),
                            locale: 'fr',
                          ),
                          style: TextStyle(
                            color: unread > 0
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLastMessagePreview(lastMsg),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
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
    );
  }

  Widget _buildAvatar(UserModel? user) {
    if (user == null) {
      return Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: AppTheme.textSecondary),
      );
    }

    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF03DAC6),
      const Color(0xFFFF6B9D),
      const Color(0xFFFFB347),
      const Color(0xFF4FC3F7),
    ];
    final colorIndex = user.username.codeUnitAt(0) % colors.length;

    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors[colorIndex],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (user.isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLastMessagePreview(dynamic lastMsg) {
    if (lastMsg == null) {
      return const Text(
        'Aucun message',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      );
    }

    final isMe = lastMsg.senderId == currentUserId;
    final prefix = isMe ? 'Vous: ' : '';

    String preview;
    IconData? icon;

    switch (lastMsg.type.name) {
      case 'image':
        preview = '${prefix}Photo';
        icon = Icons.image_outlined;
        break;
      case 'video':
        preview = '${prefix}Vidéo';
        icon = Icons.videocam_outlined;
        break;
      default:
        preview = '$prefix${lastMsg.content ?? ''}';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            preview,
            style: TextStyle(
              color: conversation.unreadCount > 0
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: conversation.unreadCount > 0
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
