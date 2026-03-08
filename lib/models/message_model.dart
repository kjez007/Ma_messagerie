import 'package:messagerie/utils/constants.dart';

enum MessageType { text, image, video }

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final MessageType type;
  final String? content;       // Texte ou URL media
  final String? mediaUrl;      // URL publique du media
  final String? thumbnailUrl;  // Miniature pour vidéos
  final double? mediaWidth;
  final double? mediaHeight;
  final int? mediaDuration;    // Durée vidéo en secondes
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.type,
    this.content,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaWidth,
    this.mediaHeight,
    this.mediaDuration,
    this.isRead = false,
    required this.createdAt,
  });

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isVideo => type == MessageType.video;

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? AppConstants.textType;
    final type = switch (typeStr) {
      AppConstants.imageType => MessageType.image,
      AppConstants.videoType => MessageType.video,
      _ => MessageType.text,
    };

    return MessageModel(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      senderName: map['profiles']?['username'] as String?,
      senderAvatar: map['profiles']?['avatar_url'] as String?,
      type: type,
      content: map['content'] as String?,
      mediaUrl: map['media_url'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      mediaWidth: (map['media_width'] as num?)?.toDouble(),
      mediaHeight: (map['media_height'] as num?)?.toDouble(),
      mediaDuration: map['media_duration'] as int?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(
          map['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    final typeStr = switch (type) {
      MessageType.image => AppConstants.imageType,
      MessageType.video => AppConstants.videoType,
      MessageType.text => AppConstants.textType,
    };

    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'type': typeStr,
      'content': content,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'media_width': mediaWidth,
      'media_height': mediaHeight,
      'media_duration': mediaDuration,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
