import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:messagerie/models/conversation_model.dart';
import 'package:messagerie/models/message_model.dart';
import 'package:messagerie/utils/constants.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  String get _currentUserId => _client.auth.currentUser!.id;

  // ═══════════════════════════════════════════════════════
  //  CONVERSATIONS
  // ═══════════════════════════════════════════════════════

  /// Récupérer toutes les conversations de l'utilisateur
  Future<List<ConversationModel>> getConversations() async {
    final data = await _client
        .from(AppConstants.conversationsTable)
        .select('''
          *,
          conversation_participants!inner(
            user_id,
            profiles(id, username, avatar_url, is_online, last_seen)
          )
        ''')
        .order('updated_at', ascending: false);

    final conversations = <ConversationModel>[];

    for (final conv in data as List) {
      // Vérifier que l'utilisateur courant est participant
      final participants = conv['conversation_participants'] as List;
      final isParticipant = participants.any(
        (p) => p['user_id'] == _currentUserId,
      );
      if (!isParticipant) continue;

      // Récupérer le dernier message
      final lastMessages = await _client
          .from(AppConstants.messagesTable)
          .select('*, profiles(username, avatar_url)')
          .eq('conversation_id', conv['id'] as String)
          .order('created_at', ascending: false)
          .limit(1);

      Map<String, dynamic>? lastMessageData;
      if ((lastMessages as List).isNotEmpty) {
        lastMessageData = lastMessages.first as Map<String, dynamic>;
        conv['last_message'] = lastMessageData;
      }

      // Compter les messages non lus
      final unread = await _client
          .from(AppConstants.messagesTable)
          .select('id')
          .eq('conversation_id', conv['id'] as String)
          .eq('is_read', false)
          .neq('sender_id', _currentUserId)
          .count(CountOption.exact);

      conv['unread_count'] = unread.count;

      conversations.add(ConversationModel.fromMap(conv));
    }

    return conversations;
  }

  /// Créer ou récupérer une conversation privée
  Future<ConversationModel> getOrCreateDirectConversation(
      String otherUserId) async {
    // Chercher une conversation existante entre les deux utilisateurs
    final existing = await _client.rpc(
      'get_direct_conversation',
      params: {
        'user1_id': _currentUserId,
        'user2_id': otherUserId,
      },
    );

    if (existing != null && existing.isNotEmpty) {
      final convId = existing[0]['id'] as String;
      return getConversationById(convId);
    }

    // Créer une nouvelle conversation
    final convId = _uuid.v4();
    await _client.from(AppConstants.conversationsTable).insert({
      'id': convId,
      'is_group': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Ajouter les participants
    await _client.from(AppConstants.participantsTable).insert([
      {
        'conversation_id': convId,
        'user_id': _currentUserId,
        'joined_at': DateTime.now().toIso8601String(),
      },
      {
        'conversation_id': convId,
        'user_id': otherUserId,
        'joined_at': DateTime.now().toIso8601String(),
      },
    ]);

    return getConversationById(convId);
  }

  /// Récupérer une conversation par son ID
  Future<ConversationModel> getConversationById(String convId) async {
    final data = await _client
        .from(AppConstants.conversationsTable)
        .select('''
          *,
          conversation_participants(
            user_id,
            profiles(id, username, avatar_url, is_online, last_seen, email, created_at)
          )
        ''')
        .eq('id', convId)
        .single();

    return ConversationModel.fromMap(data);
  }

  // ═══════════════════════════════════════════════════════
  //  MESSAGES
  // ═══════════════════════════════════════════════════════

  /// Récupérer les messages d'une conversation
  Future<List<MessageModel>> getMessages(String conversationId,
      {int limit = 50, int offset = 0}) async {
    final data = await _client
        .from(AppConstants.messagesTable)
        .select('*, profiles(username, avatar_url)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final messages =
        (data as List).map((e) => MessageModel.fromMap(e)).toList();

    // Marquer comme lus
    unawaited(_markMessagesAsRead(conversationId));

    return messages.reversed.toList();
  }

  /// Stream temps réel des nouveaux messages
  Stream<MessageModel> subscribeToMessages(String conversationId) {
    return _client
        .from(AppConstants.messagesTable)
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((data) => data.map((e) => MessageModel.fromMap(e)).toList())
        .asyncExpand((messages) async* {
          // Seulement le dernier message reçu
          if (messages.isNotEmpty) {
            yield messages.last;
          }
        });
  }

  /// Stream temps réel des conversations (pour la liste)
  RealtimeChannel subscribeToConversationUpdates(
    String conversationId,
    void Function(Map<String, dynamic>) onNewMessage,
  ) {
    return _client
        .channel('conv_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => onNewMessage(payload.newRecord),
        )
        .subscribe();
  }

  /// Envoyer un message texte
  Future<MessageModel> sendTextMessage({
    required String conversationId,
    required String content,
  }) async {
    return _sendMessage(
      conversationId: conversationId,
      type: AppConstants.textType,
      content: content,
    );
  }

  /// Envoyer une image
  Future<MessageModel> sendImageMessage({
    required String conversationId,
    required String mediaUrl,
    double? width,
    double? height,
  }) async {
    return _sendMessage(
      conversationId: conversationId,
      type: AppConstants.imageType,
      mediaUrl: mediaUrl,
      mediaWidth: width,
      mediaHeight: height,
    );
  }

  /// Envoyer une vidéo
  Future<MessageModel> sendVideoMessage({
    required String conversationId,
    required String mediaUrl,
    String? thumbnailUrl,
    int? duration,
  }) async {
    return _sendMessage(
      conversationId: conversationId,
      type: AppConstants.videoType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      mediaDuration: duration,
    );
  }

  /// Envoi générique
  Future<MessageModel> _sendMessage({
    required String conversationId,
    required String type,
    String? content,
    String? mediaUrl,
    String? thumbnailUrl,
    double? mediaWidth,
    double? mediaHeight,
    int? mediaDuration,
  }) async {
    final messageId = _uuid.v4();
    final now = DateTime.now();

    final messageData = {
      'id': messageId,
      'conversation_id': conversationId,
      'sender_id': _currentUserId,
      'type': type,
      'content': content,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'media_width': mediaWidth,
      'media_height': mediaHeight,
      'media_duration': mediaDuration,
      'is_read': false,
      'created_at': now.toIso8601String(),
    };

    await _client.from(AppConstants.messagesTable).insert(messageData);

    // Mettre à jour la conversation
    await _client.from(AppConstants.conversationsTable).update({
      'updated_at': now.toIso8601String(),
    }).eq('id', conversationId);

    // Récupérer le message avec le profil
    final saved = await _client
        .from(AppConstants.messagesTable)
        .select('*, profiles(username, avatar_url)')
        .eq('id', messageId)
        .single();

    return MessageModel.fromMap(saved);
  }

  /// Marquer les messages comme lus
  Future<void> _markMessagesAsRead(String conversationId) async {
    await _client
        .from(AppConstants.messagesTable)
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .eq('is_read', false)
        .neq('sender_id', _currentUserId);
  }

  /// Supprimer un message
  Future<void> deleteMessage(String messageId) async {
    await _client
        .from(AppConstants.messagesTable)
        .delete()
        .eq('id', messageId)
        .eq('sender_id', _currentUserId);
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
