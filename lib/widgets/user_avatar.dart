import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:messagerie/models/user_model.dart';
import 'package:messagerie/utils/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double size;
  final bool showOnlineIndicator;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 44,
    this.showOnlineIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildAvatar(),
        if (showOnlineIndicator && user.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppTheme.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.background,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar() {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: user.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildInitialsAvatar(),
          errorWidget: (_, __, ___) => _buildInitialsAvatar(),
        ),
      );
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    // Générer une couleur basée sur le nom
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFF03DAC6),
      const Color(0xFFFF6B9D),
      const Color(0xFFFFB347),
      const Color(0xFF4FC3F7),
      const Color(0xFFAED581),
    ];
    final colorIndex =
        user.username.codeUnitAt(0) % colors.length;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[colorIndex],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user.initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
