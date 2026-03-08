import 'package:flutter/material.dart';
import 'package:messagerie/models/conversation_model.dart';
import 'package:messagerie/models/user_model.dart';
import 'package:messagerie/services/auth_service.dart';
import 'package:messagerie/services/chat_service.dart';
import 'package:messagerie/screens/auth/login_screen.dart';
import 'package:messagerie/screens/chat/chat_screen.dart';
import 'package:messagerie/widgets/conversation_tile.dart';
import 'package:messagerie/widgets/user_avatar.dart';
import 'package:messagerie/utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _chatService = ChatService();

  UserModel? _currentUser;
  List<ConversationModel> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentProfile();
      final conversations = await _chatService.getConversations();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _conversations = conversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showNewChatDialog() async {
    final searchController = TextEditingController();
    List<UserModel> results = [];
    bool searching = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nouveau message',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un utilisateur...',
                      prefixIcon:
                          Icon(Icons.search, color: AppTheme.textSecondary),
                    ),
                    onChanged: (value) async {
                      if (value.length < 2) {
                        setModalState(() => results = []);
                        return;
                      }
                      setModalState(() => searching = true);
                      final found = await _authService.searchUsers(value);
                      setModalState(() {
                        results = found;
                        searching = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (searching)
                    const CircularProgressIndicator(color: AppTheme.primary),
                  if (!searching && results.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final user = results[i];
                        return ListTile(
                          leading: UserAvatar(user: user, size: 44),
                          title: Text(
                            user.username,
                            style:
                                const TextStyle(color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            user.email,
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _openOrCreateConversation(user);
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openOrCreateConversation(UserModel otherUser) async {
    try {
      final conv = await _chatService
          .getOrCreateDirectConversation(otherUser.id);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversation: conv,
              currentUser: _currentUser!,
            ),
          ),
        );
        _loadData(); // Refresh après retour
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: UserAvatar(user: _currentUser!, size: 36),
            ),
          PopupMenuButton<String>(
            color: AppTheme.surface,
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') _signOut();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppTheme.error, size: 18),
                    SizedBox(width: 8),
                    Text('Déconnexion',
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: AppTheme.divider,
                      indent: 72,
                      height: 1,
                    ),
                    itemBuilder: (_, i) {
                      final conv = _conversations[i];
                      return ConversationTile(
                        conversation: conv,
                        currentUserId: _currentUser?.id ?? '',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversation: conv,
                                currentUser: _currentUser!,
                              ),
                            ),
                          );
                          _loadData();
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucune conversation',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Commencez une nouvelle conversation\nen appuyant sur le bouton +',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
