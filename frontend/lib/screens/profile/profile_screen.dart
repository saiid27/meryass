import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/extensions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editingUsername = false;
  final _usernameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameCtrl.text = context.read<AuthProvider>().user?.username ?? '';
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null || !mounted) return;

    try {
      await ApiService.uploadAvatar(image.path);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _saveUsername() async {
    final newUsername = _usernameCtrl.text.trim();
    if (newUsername.isEmpty) return;
    try {
      await ApiService.updateProfile({'username': newUsername});
      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      setState(() => _editingUsername = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final avatarUrl = user.avatar != null
        ? AppConstants.avatarUrl(user.avatar!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('profile')),
        actions: [
          const LangToggleButton(),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await auth.logout();
              if (!mounted) return;
              navigator.popUntil((r) => r.isFirst);
            },
            child: Text(
              context.tr('logout'),
              style: const TextStyle(color: AppTheme.red),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildAvatar(avatarUrl, user.username),
            const SizedBox(height: 24),
            _buildUsernameSection(user.username),
            const SizedBox(height: 8),
            Text(
              user.email ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildStatsGrid(user),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String username) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: AppTheme.primary,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  username.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surface, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameSection(String username) {
    if (_editingUsername) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _usernameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('username_label'),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.primaryLight),
            onPressed: _saveUsername,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38),
            onPressed: () => setState(() => _editingUsername = false),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          username,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _editingUsername = true),
          child: const Icon(Icons.edit, color: Colors.white38, size: 18),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(dynamic user) {
    final winRate = ((user.winRate as double) * 100).toStringAsFixed(1);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.8,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _statCard(
          context.tr('wins'),
          '${user.wins}',
          Icons.emoji_events,
          AppTheme.gold,
        ),
        _statCard(
          context.tr('losses'),
          '${user.losses}',
          Icons.sentiment_dissatisfied,
          AppTheme.red,
        ),
        _statCard(
          context.tr('games'),
          '${user.gamesPlayed}',
          Icons.style,
          AppTheme.primaryLight,
        ),
        _statCard(
          context.tr('win_rate'),
          '$winRate%',
          Icons.bar_chart,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
