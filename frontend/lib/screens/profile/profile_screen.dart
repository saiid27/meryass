import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
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
  final _searchPhoneCtrl = TextEditingController();
  UserModel? _foundUser;
  String? _searchError;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.text = context.read<AuthProvider>().user?.username ?? '';
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _searchPhoneCtrl.dispose();
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

  Future<void> _searchPlayer() async {
    final phone = _searchPhoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
      _foundUser = null;
    });
    try {
      final data = await ApiService.searchUserByPhone(phone);
      if (!mounted) return;
      setState(() {
        _foundUser = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
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
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          children: [
            _buildAvatar(avatarUrl, user.username),
            const SizedBox(height: 14),
            _buildUsernameSection(user.username),
            const SizedBox(height: 4),
            Text(
              user.phone ?? '',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildRechargeButton(),
            const SizedBox(height: 14),
            _buildStatsGrid(user),
            const SizedBox(height: 18),
            _buildPlayerSearch(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String username) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppTheme.primary,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  username.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
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
              width: 32,
              height: 32,
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
            fontSize: 22,
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

  Widget _buildStatsGrid(UserModel user) {
    final winRate = (user.winRate * 100).toStringAsFixed(1);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
          context.tr('rounds_played'),
          '${user.roundsPlayed}',
          Icons.casino_outlined,
          AppTheme.primaryLight,
        ),
        _statCard(
          context.tr('rank'),
          '#${user.rank}',
          Icons.leaderboard,
          const Color(0xFF4FC3F7),
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

  Widget _buildRechargeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RechargeScreen()),
        ),
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: Text(context.tr('recharge')),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerSearch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('search_player'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('search_by_phone'),
              prefixIcon: const Icon(Icons.phone_outlined),
              suffixIcon: IconButton(
                onPressed: _searching ? null : _searchPlayer,
                icon: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _searchPlayer(),
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 10),
            Text(_searchError!, style: const TextStyle(color: AppTheme.red)),
          ],
          if (_foundUser != null) ...[
            const SizedBox(height: 14),
            _searchedPlayerCard(_foundUser!),
          ],
        ],
      ),
    );
  }

  Widget _searchedPlayerCard(UserModel user) {
    final winRate = (user.winRate * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.username,
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(user.phone ?? '', style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _miniStat(context.tr('wins'), '${user.wins}'),
              _miniStat(context.tr('losses'), '${user.losses}'),
              _miniStat(context.tr('rounds_played'), '${user.roundsPlayed}'),
              _miniStat(context.tr('rank'), '#${user.rank}'),
              _miniStat(context.tr('win_rate'), '$winRate%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 52) / 2,
      height: 72,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RechargeScreen extends StatelessWidget {
  const RechargeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('recharge_title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.gold,
                size: 58,
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('recharge_coming_soon'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
