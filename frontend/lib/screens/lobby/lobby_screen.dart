import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
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
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: Text(context.tr('create_room')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: context.tr('room_name')),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isPrivate,
                    onChanged: (v) => setS(() => isPrivate = v ?? false),
                    activeColor: AppTheme.primaryLight,
                  ),
                  Text(context.tr('private_room')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _createRoom(nameCtrl.text.trim(), isPrivate: isPrivate);
              },
              child: Text(context.tr('create')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom(String name, {bool isPrivate = false}) async {
    if (name.isEmpty) return;
    final room = await context
        .read<RoomProvider>()
        .createRoom(name, isPrivate: isPrivate);
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
              child: Text(context.tr('cancel'))),
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
    final success =
        await context.read<RoomProvider>().joinRoom(code, spectator: spectator);
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
        title: Text(context.tr('app_title'),
            style: const TextStyle(
                color: AppTheme.gold, fontWeight: FontWeight.bold)),
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
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
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
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showJoinByCodeDialog,
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text(context.tr('join_by_code')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.gold,
                side: const BorderSide(color: AppTheme.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
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
            Text(context.tr('no_rooms'),
                style: const TextStyle(color: Colors.white54)),
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

  const _RoomCard(
      {required this.room, required this.onJoin, required this.onSpectate});

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
                  Text(room.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${room.playerCount}/4',
                          style: const TextStyle(color: Colors.white54)),
                      const SizedBox(width: 8),
                      if (room.spectatorCount > 0)
                        Text('${room.spectatorCount} 👁',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
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
                        horizontal: 16, vertical: 8)),
                child: Text(context.tr('play')),
              )
            else
              TextButton(
                onPressed: onSpectate,
                child: Text(context.tr('watch'),
                    style: const TextStyle(color: AppTheme.gold)),
              ),
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
