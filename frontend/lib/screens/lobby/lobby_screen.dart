import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/extensions.dart';
import '../profile/profile_screen.dart';
import 'room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomProvider>().fetchRooms();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _showCreateRoomDialog() {
    final nameCtrl = TextEditingController();
    bool isPrivate = false;
    String gameType = 'bilt';
    String scoringMode = 'zero';
    int step = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final canContinue = step != 0 || nameCtrl.text.trim().isNotEmpty;
          final totalSteps = gameType == 'torneeka' ? 2 : 3;
          final isLastStep = step >= totalSteps - 1;
          final titles = [
            context.tr('room_name'),
            context.tr('game_type'),
            context.tr('scoring_mode'),
          ];

          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: Text(context.tr('create_room')),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CreateRoomSteps(
                      currentStep: step > totalSteps - 1
                          ? totalSteps - 1
                          : step,
                      totalSteps: totalSteps,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      titles[step],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: switch (step) {
                        0 => TextField(
                          key: const ValueKey('room-name-step'),
                          controller: nameCtrl,
                          onChanged: (_) => setS(() {}),
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: context.tr('room_name'),
                          ),
                        ),
                        1 => Column(
                          key: const ValueKey('game-type-step'),
                          children: [
                            _CreateOptionTile(
                              label: context.tr('bilt'),
                              selected: gameType == 'bilt',
                              icon: Icons.check,
                              onTap: () => setS(() => gameType = 'bilt'),
                            ),
                            const SizedBox(height: 10),
                            _CreateOptionTile(
                              label: context.tr('torneeka'),
                              selected: gameType == 'torneeka',
                              icon: Icons.check,
                              onTap: () => setS(() => gameType = 'torneeka'),
                            ),
                          ],
                        ),
                        _ => Column(
                          key: const ValueKey('scoring-step'),
                          children: [
                            _CreateOptionTile(
                              label: context.tr('score_from_zero'),
                              selected: scoringMode == 'zero',
                              icon: Icons.check,
                              onTap: () => setS(() => scoringMode = 'zero'),
                            ),
                            const SizedBox(height: 10),
                            _CreateOptionTile(
                              label: context.tr('score_from_26'),
                              trailing: context.tr('coming_soon'),
                              selected: false,
                              enabled: false,
                              icon: Icons.lock_outline,
                            ),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              value: isPrivate,
                              onChanged: (v) =>
                                  setS(() => isPrivate = v ?? false),
                              activeColor: AppTheme.primaryLight,
                              contentPadding: EdgeInsets.zero,
                              title: Text(context.tr('private_room')),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ],
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (step == 0) {
                    Navigator.pop(ctx);
                  } else {
                    setS(() => step -= 1);
                  }
                },
                child: Text(
                  step == 0 ? context.tr('cancel') : context.tr('back'),
                ),
              ),
              ElevatedButton(
                onPressed: !canContinue
                    ? null
                    : () async {
                        if (!isLastStep) {
                          setS(() => step += 1);
                          return;
                        }
                        Navigator.pop(ctx);
                        await _createRoom(
                          nameCtrl.text.trim(),
                          gameType: gameType,
                          scoringMode: scoringMode,
                          isPrivate: isPrivate,
                        );
                      },
                child: Text(
                  isLastStep ? context.tr('create') : context.tr('next'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createRoom(
    String name, {
    String gameType = 'bilt',
    String scoringMode = 'zero',
    bool isPrivate = false,
  }) async {
    if (name.isEmpty) return;
    final room = await context.read<RoomProvider>().createRoom(
      name,
      gameType: gameType,
      scoringMode: scoringMode,
      isPrivate: isPrivate,
    );
    if (room != null && mounted) {
      _navigateToRoom(room);
    }
  }

  void _showJoinByCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(context.tr('join_by_code_title')),
        content: TextField(
          controller: _codeCtrl,
          decoration: InputDecoration(
            labelText: context.tr('join_by_code_title'),
            hintText: context.tr('room_code_hint'),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _joinRoom(_codeCtrl.text.trim());
            },
            child: Text(context.tr('join')),
          ),
        ],
      ),
    );
  }

  Future<void> _joinRoom(String code, {bool spectator = false}) async {
    if (code.isEmpty) return;
    final success = await context.read<RoomProvider>().joinRoom(
      code,
      spectator: spectator,
    );
    if (success && mounted) {
      final room = context.read<RoomProvider>().currentRoom;
      if (room != null) _navigateToRoom(room);
    }
  }

  void _navigateToRoom(RoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomScreen(roomCode: room.code)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roomProv = context.watch<RoomProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('app_title'),
          style: const TextStyle(
            color: AppTheme.gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: roomProv.fetchRooms,
          ),
          const LangToggleButton(),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: AppTheme.primary,
              child: Text(
                auth.user?.username.substring(0, 1).toUpperCase() ?? 'M',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildActionButtons(),
          const Divider(height: 1),
          Expanded(child: _buildRoomList(roomProv)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add),
              label: Text(context.tr('create_room')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showJoinByCodeDialog,
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text(
                context.tr('join_by_code'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.gold,
                side: const BorderSide(color: AppTheme.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showPlayerSearchDialog,
              icon: const Icon(Icons.search),
              label: Text(
                context.tr('search_player_short'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryLight,
                side: const BorderSide(color: AppTheme.primaryLight),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerSearchDialog() {
    final phoneCtrl = TextEditingController();
    UserModel? foundUser;
    String? error;
    bool searching = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> search() async {
            final phone = phoneCtrl.text.trim();
            if (phone.isEmpty) return;
            setS(() {
              searching = true;
              error = null;
              foundUser = null;
            });
            try {
              final data = await ApiService.searchUserByPhone(phone);
              if (!ctx.mounted) return;
              setS(() {
                foundUser = UserModel.fromJson(
                  data['user'] as Map<String, dynamic>,
                );
              });
            } on ApiException catch (e) {
              if (!ctx.mounted) return;
              setS(() => error = e.message);
            } finally {
              if (ctx.mounted) setS(() => searching = false);
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            title: Text(context.tr('search_player')),
            content: SizedBox(
              width: 330,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.tr('search_by_phone'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    onSubmitted: (_) => search(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: AppTheme.red)),
                  ],
                  if (foundUser != null) ...[
                    const SizedBox(height: 14),
                    _PlayerSearchResult(user: foundUser!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('cancel')),
              ),
              ElevatedButton.icon(
                onPressed: searching ? null : search,
                icon: searching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(context.tr('search_player_short')),
              ),
            ],
          );
        },
      ),
    ).whenComplete(phoneCtrl.dispose);
  }

  Widget _buildRoomList(RoomProvider prov) {
    if (prov.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (prov.rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.style_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              context.tr('no_rooms'),
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: prov.fetchRooms,
              child: Text(context.tr('refresh')),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prov.rooms.length,
      itemBuilder: (_, i) => _RoomCard(
        room: prov.rooms[i],
        onJoin: () => _joinRoom(prov.rooms[i].code),
        onSpectate: () => _joinRoom(prov.rooms[i].code, spectator: true),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onJoin;
  final VoidCallback onSpectate;

  const _RoomCard({
    required this.room,
    required this.onJoin,
    required this.onSpectate,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = room.playerCount >= 4;
    final isPlaying = room.status == 'playing';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.style, color: AppTheme.primaryLight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${room.playerCount}/4',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(width: 8),
                      if (room.spectatorCount > 0)
                        Text(
                          '${room.spectatorCount} 👁',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      const Spacer(),
                      _StatusBadge(status: room.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isFull && !isPlaying)
              ElevatedButton(
                onPressed: onJoin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(context.tr('play')),
              )
            else
              TextButton(
                onPressed: onSpectate,
                child: Text(
                  context.tr('watch'),
                  style: const TextStyle(color: AppTheme.gold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateRoomSteps extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _CreateRoomSteps({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < totalSteps; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: i == currentStep ? 28 : 9,
            height: 9,
            decoration: BoxDecoration(
              color: i <= currentStep ? AppTheme.gold : Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          if (i < totalSteps - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _CreateOptionTile extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool selected;
  final bool enabled;
  final IconData icon;
  final VoidCallback? onTap;

  const _CreateOptionTile({
    required this.label,
    this.trailing,
    required this.selected,
    this.enabled = true,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = !enabled
        ? Colors.white38
        : selected
        ? const Color(0xFF132015)
        : Colors.white;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.gold : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.gold : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'playing':
        color = AppTheme.gold;
        label = context.tr('status_playing');
        break;
      case 'finished':
        color = Colors.grey;
        label = context.tr('status_finished');
        break;
      default:
        color = AppTheme.primaryLight;
        label = context.tr('status_waiting');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _PlayerSearchResult extends StatelessWidget {
  final UserModel user;

  const _PlayerSearchResult({required this.user});

  @override
  Widget build(BuildContext context) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if ((user.phone ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              user.phone!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _PlayerSearchChip(
                label: context.tr('wins'),
                value: '${user.wins}',
              ),
              _PlayerSearchChip(
                label: context.tr('losses'),
                value: '${user.losses}',
              ),
              _PlayerSearchChip(
                label: context.tr('rounds_played'),
                value: '${user.roundsPlayed}',
              ),
              _PlayerSearchChip(
                label: context.tr('rank'),
                value: '#${user.rank}',
              ),
              _PlayerSearchChip(
                label: context.tr('win_rate'),
                value: '$winRate%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerSearchChip extends StatelessWidget {
  final String label;
  final String value;

  const _PlayerSearchChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }
}
