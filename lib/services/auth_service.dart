import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:messagerie/models/user_model.dart';
import 'package:messagerie/utils/constants.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Inscription
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Erreur lors de la création du compte');
    }

    // Créer le profil utilisateur
    final profile = {
      'id': response.user!.id,
      'email': email,
      'username': username,
      'is_online': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from(AppConstants.profilesTable).upsert(profile);

    return UserModel(
      id: response.user!.id,
      email: email,
      username: username,
      isOnline: true,
      createdAt: DateTime.now(),
    );
  }

  /// Connexion
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Email ou mot de passe incorrect');
    }

    // Mettre à jour le statut en ligne
    await _client.from(AppConstants.profilesTable).update({
      'is_online': true,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', response.user!.id);

    final profileData = await _client
        .from(AppConstants.profilesTable)
        .select()
        .eq('id', response.user!.id)
        .single();

    return UserModel.fromMap(profileData);
  }

  /// Déconnexion
  Future<void> signOut() async {
    final userId = currentUserId;
    if (userId != null) {
      await _client.from(AppConstants.profilesTable).update({
        'is_online': false,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    }
    await _client.auth.signOut();
  }

  /// Récupérer le profil courant
  Future<UserModel?> getCurrentProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final data = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Rechercher des utilisateurs
  Future<List<UserModel>> searchUsers(String query) async {
    final userId = currentUserId;
    if (userId == null) return [];

    final data = await _client
        .from(AppConstants.profilesTable)
        .select()
        .neq('id', userId)
        .ilike('username', '%$query%')
        .limit(20);

    return (data as List).map((e) => UserModel.fromMap(e)).toList();
  }

  /// Mettre à jour le profil
  Future<void> updateProfile({
    String? username,
    String? avatarUrl,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _client
        .from(AppConstants.profilesTable)
        .update(updates)
        .eq('id', userId);
  }

  /// Mettre à jour la présence
  Future<void> updatePresence(bool isOnline) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client.from(AppConstants.profilesTable).update({
      'is_online': isOnline,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }
}
