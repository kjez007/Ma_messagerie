import 'package:messagerie/models/message_model.dart';
import 'package:messagerie/models/user_model.dart';

class ConversationModel {
  final String id;
  final String? name;        // Pour les groupes
  final bool isGroup;
  final String? groupAvatar;
  final List<UserModel> participants;
  final MessageModel? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationModel({
    required this.id,
    this.name,
    this.isGroup = false,
    this.groupAvatar,
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Retourne l'autre participant dans une conv à 2
  UserModel? otherParticipant(String currentUserId) {
    try {
      return participants.firstWhere((p) => p.id != currentUserId);
    } catch (_) {
      return null;
    }
  }

  /// Nom affiché de la conversation
  String displayName(String currentUserId) {
    if (isGroup && name != null) return name!;
    final other = otherParticipant(currentUserId);
    return other?.username ?? 'Conversation';
  }

  /// Avatar affiché
  String? displayAvatar(String currentUserId) {
    if (isGroup) return groupAvatar;
    return otherParticipant(currentUserId)?.avatarUrl;
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map) {
    final participants = <UserModel>[];

    if (map['conversation_participants'] != null) {
      for (final p in map['conversation_participants'] as List) {
        if (p['profiles'] != null) {
          participants.add(UserModel.fromMap(p['profiles'] as Map<String, dynamic>));
        }
      }
    }

    MessageModel? lastMessage;
    if (map['last_message'] != null) {
      lastMessage = MessageModel.fromMap(map['last_message'] as Map<String, dynamic>);
    }

    return ConversationModel(
      id: map['id'] as String,
      name: map['name'] as String?,
      isGroup: map['is_group'] as bool? ?? false,
      groupAvatar: map['group_avatar'] as String?,
      participants: participants,
      lastMessage: lastMessage,
      unreadCount: map['unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(
          map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  ConversationModel copyWith({
    MessageModel? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id,
      name: name,
      isGroup: isGroup,
      groupAvatar: groupAvatar,
      participants: participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
