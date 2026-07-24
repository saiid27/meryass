import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/extensions.dart';
import '../game/game_screen.dart';

class RoomScreen extends StatefulWidget {
  final String roomCode;
  const RoomScreen({super.key, required this.roomCode});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  bool _navigating = false;
  GameProvider? _gameProv;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  void _setup() {
    final auth = context.read<AuthProvider>();
    final roomProv = context.read<RoomProvider>();
    final gameProv = context.read<GameProvider>();
    _gameProv = gameProv;
    final token = auth.token!;

    roomProv.setupSocketListeners(token, widget.roomCode);
    gameProv.setupSocketListeners(token, widget.roomCode);
    roomProv.joinRoomSocket(token, widget.roomCode);

    gameProv.addListener(_onGameStarted);
  }

  void _onGameStarted() {
    final gameProv = _gameProv;
    if (gameProv == null) return;
    if (gameProv.gameStarted && !_navigating && mounted) {
      _navigating = true;
      gameProv.removeListener(_onGameStarted);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(roomCode: widget.roomCode),
        ),
      );
    }
  }

  Future<void> _leaveRoom() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final roomProv = context.read<RoomProvider>();
    roomProv.leaveCurrentRoom(auth.token!, widget.roomCode);
    try {
      await ApiService.leaveRoom(widget.roomCode);
    } catch (_) {}
  }

  @override
  void dispose() {
    _gameProv?.removeListener(_onGameStarted);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roomProv = context.watch<RoomProvider>();
    final room = roomProv.currentRoom;
    final players = roomProv.gamePlayers;
    final spectators = roomProv.spectators;
    final myUserId = auth.user?.id;

    final myMembership = roomProv.players
        .where((p) => p.user?.id == myUserId)
        .firstOrNull;
    final isSpectator = myMembership?.isSpectator ?? true;
    final isReady = myMembership?.isReady ?? false;
    final isSupervisor = room?.creator?.id == myUserId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) return;
        await _leaveRoom();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(room?.name ?? context.tr('room')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _leaveRoom();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            if (room != null)
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: context.tr('copy_code'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: room.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('code_copied'))),
                  );
                },
              ),
          ],
        ),
        body: Column(
          children: [
            if (room != null) _buildCodeBadge(room),
            const SizedBox(height: 16),
            Expanded(
              child: _buildPlayerGrid(players, myUserId, isSupervisor, room),
            ),
            if (spectators.isNotEmpty)
              _buildSpectatorsList(spectators, isSupervisor, room),
            const SizedBox(height: 16),
            if (!isSpectator)
              _buildBottomActions(
                auth,
                isReady,
                players,
                isSupervisor: isSupervisor,
                room: room,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBadge(RoomModel room) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.vpn_key_outlined, color: AppTheme.gold, size: 20),
          const SizedBox(width: 8),
          Text(
            '${context.tr('room_code_label')} : ${room.code}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerGrid(
    List<RoomPlayerModel> players,
    int? myUserId,
    bool isSupervisor,
    RoomModel? room,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 4,
      itemBuilder: (_, i) {
        final player = players.firstWhere(
          (p) => p.position == i,
          orElse: () => RoomPlayerModel(id: -1, roomId: -1, position: i),
        );
        final isEmpty = player.id == -1;
        final isMe = player.user?.id == myUserId;
        final isCreator = player.user?.id == room?.creator?.id;
        final team = i % 2 == 0 ? 0 : 1;

        return Container(
          decoration: BoxDecoration(
            color: isEmpty
                ? AppTheme.cardBackground.withValues(alpha: 0.5)
                : (isMe
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : AppTheme.cardBackground),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe
                  ? AppTheme.primaryLight
                  : (team == 0
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3)),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isEmpty) ...[
                const Icon(
                  Icons.person_add_outlined,
                  color: Colors.white24,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.tr('position')} ${i + 1}',
                  style: const TextStyle(color: Colors.white24),
                ),
              ] else ...[
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    CircleAvatar(
                      backgroundColor: team == 0 ? Colors.blue : Colors.orange,
                      radius: 24,
                      child: Text(
                        (player.user?.username ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (player.isReady)
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryLight,
                          size: 16,
                        ),
                      ),
                    if (isSupervisor &&
                        !isMe &&
                        !isCreator &&
                        room?.status == 'waiting')
                      Positioned(
                        left: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () => _benchPlayer(player),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B2020),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_horiz,
                              size: 15,
                              color: AppTheme.gold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${player.user?.username ?? ''}${player.user?.isBot == true ? '  🤖' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isMe ? AppTheme.primaryLight : Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isCreator
                      ? context.tr('supervisor')
                      : '${context.tr('team')} ${team + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isCreator
                        ? AppTheme.gold
                        : team == 0
                        ? Colors.blue.shade300
                        : Colors.orange.shade300,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpectatorsList(
    List<RoomPlayerModel> spectators,
    bool isSupervisor,
    RoomModel? room,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility, color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${context.tr('spectators_label')} : '
                  '${spectators.map((s) => s.user?.username ?? '?').join(', ')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            ],
          ),
          if (isSupervisor && room?.status == 'waiting') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final spectator in spectators)
                  OutlinedButton.icon(
                    onPressed: () => _chooseSeatFor(spectator),
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: Text(
                      '${context.tr('seat_player')} ${spectator.user?.username ?? '?'}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _benchPlayer(RoomPlayerModel player) async {
    try {
      await context.read<RoomProvider>().benchPlayer(
        widget.roomCode,
        player.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _chooseSeatFor(RoomPlayerModel player) async {
    final position = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(context.tr('choose_seat'))),
            for (var i = 0; i < 4; i++)
              ListTile(
                leading: const Icon(Icons.event_seat),
                title: Text('${context.tr('position')} ${i + 1}'),
                subtitle: Text('${context.tr('team')} ${(i % 2) + 1}'),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (position == null) return;
    if (!mounted) return;
    try {
      await context.read<RoomProvider>().assignSeat(
        widget.roomCode,
        position,
        player.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _fillWithBots() async {
    try {
      await context.read<RoomProvider>().fillWithBots(widget.roomCode);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _buildBottomActions(
    AuthProvider auth,
    bool isReady,
    List<RoomPlayerModel> players, {
    required bool isSupervisor,
    required RoomModel? room,
  }) {
    final allReady = players.length == 4 && players.every((p) => p.isReady);
    final canFillWithBots =
        isSupervisor && room?.status == 'waiting' && players.length == 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (canFillWithBots) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _fillWithBots,
                icon: const Icon(Icons.smart_toy_outlined),
                label: Text(context.tr('add_bots')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.gold,
                  side: const BorderSide(color: AppTheme.gold),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                context.tr('add_bots_hint'),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (!isReady)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.read<RoomProvider>().setReady(
                  auth.token!,
                  widget.roomCode,
                ),
                icon: const Icon(Icons.check),
                label: Text(context.tr('ready_btn')),
              ),
            ),
          if (isReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.primaryLight),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('ready_label'),
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (players.length < 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('waiting_players'),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          else if (!allReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.tr('waiting_ready'),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
