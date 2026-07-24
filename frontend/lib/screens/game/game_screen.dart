import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/card_model.dart';
import '../../models/game_state_model.dart';
import '../../models/room_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/room_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/extensions.dart';
import '../../widgets/playing_card.dart';

class GameScreen extends StatefulWidget {
  final String roomCode;

  const GameScreen({super.key, required this.roomCode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  CardModel? _selectedCard;
  bool _gameOverShown = false;
  Timer? _turnTicker;
  // Saved in initState so dispose() can access it without a BuildContext.
  late final GameProvider _gameProv;

  @override
  void initState() {
    super.initState();
    _gameProv = context.read<GameProvider>();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _turnTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Restore portrait FIRST — guaranteed even if provider cleanup throws.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _turnTicker?.cancel();
    _gameProv.removeSocketListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GameProvider>();
    final state = game.gameState;

    if (state == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF073D25),
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    if (game.gameWinner != null && !_gameOverShown) {
      _gameOverShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showGameOverDialog(game.gameWinner!),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF063B25),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              const Positioned.fill(child: _GameRoomBackground()),
              _buildOvalTable(size),
              _buildSeats(size, game, state),
              _buildTrick(size, game, state),
              _buildScoreBoard(size, state),
              _buildRoomBadge(),
              _buildExitButton(),
              _buildHand(size, game, auth, state),
              if (game.isMyTurn &&
                  state.status == 'playing' &&
                  _turnDelayElapsed(state))
                _buildTurnBanner(size),
              if (state.status == 'bidding')
                _buildBiddingPanel(size, game, auth, state),
              _buildCoinsButton(
                size,
                game,
                auth,
                enabled:
                    state.status == 'bidding' &&
                    game.isMyBidTurn &&
                    state.coins == null &&
                    state.acceptedBid != null,
              ),
              _buildMgButton(
                size,
                game,
                auth,
                state,
                enabled:
                    state.status == 'playing' &&
                    state.mgTarget != null &&
                    state.mgTarget!.position != game.myPosition,
              ),
              if (game.roundResult != null && game.gameWinner == null)
                _buildRoundResultOverlay(game),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOvalTable(Size size) {
    return Positioned(
      left: size.width * 0.105,
      right: size.width * 0.105,
      top: size.height * 0.18,
      bottom: size.height * 0.17,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size.height),
          color: const Color(0xFF10261B),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              spreadRadius: 3,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size.height),
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [Color(0xFF177C4A), Color(0xFF07512F)],
            ),
            border: Border.all(color: Colors.white12, width: 1.5),
          ),
          child: CustomPaint(painter: _FeltLinePainter()),
        ),
      ),
    );
  }

  Widget _buildSeats(Size size, GameProvider game, GameStateModel state) {
    final players = context.watch<RoomProvider>().gamePlayers;
    final myPosition = game.myPosition ?? 0;
    final topPosition = (myPosition + 2) % 4;
    final leftPosition = (myPosition + 1) % 4;
    final rightPosition = (myPosition + 3) % 4;

    final seatWidth = math.min(150.0, size.width * 0.18);
    final sideWidth = math.min(132.0, size.width * 0.16);
    final seatHeight = math.min(98.0, size.height * 0.25);

    return Stack(
      children: [
        Positioned(
          width: seatWidth,
          height: seatHeight,
          left: (size.width - seatWidth) / 2,
          top: 6,
          child: _playerSeat(players, topPosition, state),
        ),
        Positioned(
          width: sideWidth,
          height: seatHeight,
          left: 8,
          top: (size.height - seatHeight) / 2 - 4,
          child: _playerSeat(players, leftPosition, state),
        ),
        Positioned(
          width: sideWidth,
          height: seatHeight,
          right: 8,
          top: (size.height - seatHeight) / 2 - 4,
          child: _playerSeat(players, rightPosition, state),
        ),
        Positioned(
          width: sideWidth,
          height: seatHeight,
          left: 8,
          bottom: 4,
          child: _playerSeat(players, myPosition, state, isMe: true),
        ),
      ],
    );
  }

  Widget _playerSeat(
    List<RoomPlayerModel> players,
    int position,
    GameStateModel state, {
    bool isMe = false,
  }) {
    final player = players.where((p) => p.position == position).firstOrNull;
    final user = player?.user;
    final isBot = user?.isBot == true;
    final isActive =
        state.currentTurn == position ||
        (state.status == 'bidding' && state.biddingPlayer == position);
    final isDealer = state.dealer == position;
    final cardsPlayed = state.currentTrick.any(
      (card) => card.position == position,
    );
    final estimatedCards = math.max(
      0,
      (state.status == 'bidding' ? 5 : 8 - state.tricksPlayed) -
          (cardsPlayed ? 1 : 0),
    );
    final displayName = isBot
        ? 'Bot ${position + 1}'
        : user?.username ?? '${context.tr('position')} ${position + 1}';
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().characters.first.toUpperCase();
    final bidChoice = state.bidChoices[position];

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        if (!isMe)
          Positioned(top: 0, child: _OpponentCardFan(count: estimatedCards)),
        Positioned(
          top: isMe ? 2 : 15,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isMe ? 62 : 58,
            height: isMe ? 62 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isBot
                    ? const [Color(0xFF455A64), Color(0xFF263238)]
                    : const [Color(0xFF43A047), Color(0xFF145A32)],
              ),
              border: Border.all(
                color: isActive ? AppTheme.gold : Colors.white70,
                width: isActive ? 4 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? AppTheme.gold.withValues(alpha: 0.55)
                      : Colors.black45,
                  blurRadius: isActive ? 14 : 6,
                ),
              ],
            ),
            child: Center(
              child: isBot
                  ? const Icon(Icons.smart_toy, color: Colors.white, size: 30)
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
        if (bidChoice != null)
          Positioned(
            top: isMe ? 0 : 4,
            right: 0,
            child: _BidChoiceBadge(choice: bidChoice),
          ),
        Positioned(
          bottom: 0,
          left: 2,
          right: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFB3261E) : const Color(0xFF166B43),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 3),
              ],
            ),
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          left: 7,
          bottom: 25,
          child: Icon(
            isBot ? Icons.smart_toy_outlined : Icons.mic,
            color: isBot ? Colors.white60 : const Color(0xFF65E572),
            size: 18,
          ),
        ),
        if (isDealer)
          Positioned(
            right: 4,
            bottom: 24,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1A15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.gold, width: 2),
              ),
              child: const Center(
                child: Text(
                  'D',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        if (isActive)
          const Positioned(
            right: 5,
            top: 12,
            child: Icon(Icons.circle, color: AppTheme.gold, size: 11),
          ),
      ],
    );
  }

  Widget _buildTrick(Size size, GameProvider game, GameStateModel state) {
    final areaWidth = math.min(280.0, size.width * 0.3);
    final areaHeight = math.min(185.0, size.height * 0.46);
    final cardWidth = math.min(62.0, areaWidth * 0.23);
    final cardHeight = cardWidth * 1.42;

    return Positioned(
      width: areaWidth,
      height: areaHeight,
      left: (size.width - areaWidth) / 2,
      top: (size.height - areaHeight) / 2 - 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (state.currentTrick.isEmpty)
            Container(
              width: areaWidth * 0.55,
              height: areaHeight * 0.48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  state.status == 'bidding'
                      ? context.tr('bidding_wait')
                      : context.tr('trick_empty'),
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
            ),
          ...state.currentTrick.map((trickCard) {
            final relative =
                (trickCard.position - (game.myPosition ?? 0) + 4) % 4;
            final offsets = [
              Offset(0, areaHeight * 0.21),
              Offset(-areaWidth * 0.22, 0),
              Offset(0, -areaHeight * 0.21),
              Offset(areaWidth * 0.22, 0),
            ];
            final rotations = [0.0, -0.08, 0.04, 0.08];
            return Transform.translate(
              offset: offsets[relative],
              child: Transform.rotate(
                angle: rotations[relative],
                child: PlayingCard(
                  card: trickCard.card,
                  width: cardWidth,
                  height: cardHeight,
                ),
              ),
            );
          }),
          if (state.trumpSuit != null)
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${context.tr('trump_label')}  ${Suit.symbol(state.trumpSuit!)}',
                  style: TextStyle(
                    color: Suit.isRed(state.trumpSuit!)
                        ? const Color(0xFFFF6B6B)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHand(
    Size size,
    GameProvider game,
    AuthProvider auth,
    GameStateModel state,
  ) {
    final hand = game.myHand;
    final isMyTurn =
        game.isMyTurn && state.status == 'playing' && _turnDelayElapsed(state);
    final areaWidth = size.width * 0.69;
    final cardHeight = math.min(108.0, size.height * 0.29);
    final cardWidth = cardHeight * 0.68;
    final overlap = hand.length <= 1
        ? 0.0
        : math.min(
            cardWidth * 0.66,
            (areaWidth - cardWidth) / (hand.length - 1),
          );
    final totalWidth = hand.isEmpty
        ? 0.0
        : cardWidth + overlap * (hand.length - 1);

    return Positioned(
      left: size.width * 0.19,
      right: size.width * 0.035,
      bottom: -5,
      height: cardHeight + 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < hand.length; index++)
            Positioned(
              left: (areaWidth - totalWidth) / 2 + overlap * index,
              bottom: _selectedCard == hand[index] ? 14 : 0,
              child: Transform.rotate(
                angle: (index - (hand.length - 1) / 2) * 0.025,
                alignment: Alignment.bottomCenter,
                child: PlayingCard(
                  card: hand[index],
                  isSelected: _selectedCard == hand[index],
                  isPlayable: isMyTurn,
                  width: cardWidth,
                  height: cardHeight,
                  onTap: () =>
                      _handleCardTap(game, auth, hand[index], isMyTurn),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleCardTap(
    GameProvider game,
    AuthProvider auth,
    CardModel card,
    bool isMyTurn,
  ) {
    if (!isMyTurn) return;
    if (_selectedCard == card) {
      game.playCard(auth.token!, widget.roomCode, card);
      setState(() => _selectedCard = null);
    } else {
      setState(() => _selectedCard = card);
    }
  }

  bool _turnDelayElapsed(GameStateModel state) {
    final availableAt = state.turnAvailableAt;
    if (availableAt == null) return true;
    return DateTime.now().millisecondsSinceEpoch / 1000 >= availableAt;
  }

  Widget _buildTurnBanner(Size size) {
    return Positioned(
      bottom: math.min(116.0, size.height * 0.31),
      left: size.width * 0.37,
      right: size.width * 0.25,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF13391F).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.gold),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
          ),
          child: Text(
            context.tr('your_turn'),
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMgButton(
    Size size,
    GameProvider game,
    AuthProvider auth,
    GameStateModel state, {
    required bool enabled,
  }) {
    return Positioned(
      top: 54,
      left: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => game.mg(auth.token!, widget.roomCode) : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 72,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF6F1B17),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled ? AppTheme.gold : Colors.white54,
                width: 1.4,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 8),
              ],
            ),
            child: const Text(
              'MG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBoard(Size size, GameStateModel state) {
    final authUserId = context.read<AuthProvider>().user?.id;
    final membership = context
        .read<RoomProvider>()
        .gamePlayers
        .where((player) => player.user?.id == authUserId)
        .firstOrNull;
    final myTeam = membership?.team ?? 0;
    final theirTeam = 1 - myTeam;

    return Positioned(
      top: 8,
      left: size.width * 0.66,
      width: math.min(132.0, size.width * 0.18),
      height: 57,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8EFE9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      color: const Color(0xFFD62B1F),
                      alignment: Alignment.center,
                      child: Text(
                        context.isArabic ? 'نحن' : 'Nous',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFF1FAD45),
                      alignment: Alignment.center,
                      child: Text(
                        context.isArabic ? 'هم' : 'Eux',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _scoreValue(state.teamScores[myTeam] ?? 0),
                  Container(width: 1, color: Colors.black12),
                  _scoreValue(state.teamScores[theirTeam] ?? 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreValue(int value) {
    return Expanded(
      child: Center(
        child: Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFF142018),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildRoomBadge() {
    return Positioned(
      top: 12,
      left: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.meeting_room_outlined,
              color: Colors.white70,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              widget.roomCode,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExitButton() {
    return Positioned(
      top: 12,
      right: 14,
      child: Material(
        color: const Color(0xFFE7ECE8),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _confirmExit,
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 46,
            height: 42,
            child: Icon(
              Icons.logout_rounded,
              color: Color(0xFF2A332E),
              size: 25,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(context.tr('return_lobby')),
        content: Text(
          context.isArabic
              ? 'هل تريد مغادرة طاولة اللعب؟'
              : 'Voulez-vous quitter la table de jeu ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('return_lobby')),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Widget _buildBiddingPanel(
    Size size,
    GameProvider game,
    AuthProvider auth,
    GameStateModel state,
  ) {
    final isMyBidTurn = game.isMyBidTurn;
    final panelWidth = math.min(390.0, size.width * 0.48);
    final availableBids = _availableBidActions(state);

    return Positioned(
      width: panelWidth,
      left: (size.width - panelWidth) / 2,
      bottom: math.min(105.0, size.height * 0.28),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xEE10271C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isMyBidTurn ? AppTheme.gold : Colors.white24,
            width: 1.5,
          ),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14)],
        ),
        child: Row(
          children: [
            if (state.turnedCard != null)
              PlayingCard(card: state.turnedCard!, width: 48, height: 68),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMyBidTurn
                        ? context.tr('your_bid_turn')
                        : context.tr('bidding_wait'),
                    style: TextStyle(
                      color: isMyBidTurn ? AppTheme.gold : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isMyBidTurn) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      alignment: WrapAlignment.center,
                      children: [
                        _compactBidButton(
                          context.tr('pass'),
                          Colors.white70,
                          () => game.bid(auth.token!, widget.roomCode, 'pass'),
                        ),
                        if (availableBids.contains('to'))
                          _compactBidButton(
                            context.tr('to'),
                            AppTheme.gold,
                            () => game.bid(auth.token!, widget.roomCode, 'to'),
                          ),
                        if (availableBids.contains('sans'))
                          _compactBidButton(
                            context.tr('sans'),
                            const Color(0xFFD6A7FF),
                            () =>
                                game.bid(auth.token!, widget.roomCode, 'sans'),
                          ),
                        if (availableBids.contains('pik'))
                          _compactBidButton(
                            context.tr('pik'),
                            Colors.white,
                            () => game.bid(auth.token!, widget.roomCode, 'pik'),
                          ),
                        if (availableBids.contains('kere'))
                          _compactBidButton(
                            context.tr('kere'),
                            const Color(0xFFFF6B6B),
                            () =>
                                game.bid(auth.token!, widget.roomCode, 'kere'),
                          ),
                        if (availableBids.contains('kerew'))
                          _compactBidButton(
                            context.tr('kerew'),
                            const Color(0xFFFF8E80),
                            () =>
                                game.bid(auth.token!, widget.roomCode, 'kerew'),
                          ),
                        if (availableBids.contains('treve'))
                          _compactBidButton(
                            context.tr('treve'),
                            const Color(0xFF9AD8A3),
                            () =>
                                game.bid(auth.token!, widget.roomCode, 'treve'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinsButton(
    Size size,
    GameProvider game,
    AuthProvider auth, {
    required bool enabled,
  }) {
    final isLandscape = size.width > size.height;
    const width = 94.0;
    final bottom = isLandscape
        ? math.max(22.0, size.height * 0.08)
        : math.max(92.0, size.height * 0.11);
    return Positioned(
      width: width,
      right: isLandscape ? 18 : 14,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () => game.bid(auth.token!, widget.roomCode, 'coins')
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF6F1B17),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled ? AppTheme.gold : Colors.white54,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 8),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('coins'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  context.tr('guaranteed'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? AppTheme.gold : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactBidButton(String label, Color color, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(72, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        side: BorderSide(color: color.withValues(alpha: 0.55)),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }

  List<String> _availableBidActions(GameStateModel state) {
    if (state.coins != null) return const [];
    const strength = {
      'treve': 1,
      'kerew': 2,
      'kere': 3,
      'pik': 4,
      'sans': 5,
      'to': 6,
    };
    var currentStrength = 0;
    for (final choice in state.bidChoices.values) {
      final value = strength[choice] ?? 0;
      if (value > currentStrength) currentStrength = value;
    }
    return strength.entries
        .where((entry) => entry.value > currentStrength)
        .map((entry) => entry.key)
        .toList();
  }

  Widget _buildRoundResultOverlay(GameProvider game) {
    final result = game.roundResult!;
    final awarded = result['awarded'] as Map? ?? {};
    final teamScores = result['team_scores'] as Map? ?? {};
    int pointsFor(int team) =>
        (awarded[team] ?? awarded[team.toString()] ?? 0) as int;
    int totalFor(int team) =>
        (teamScores[team] ?? teamScores[team.toString()] ?? 0) as int;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.76),
        alignment: Alignment.center,
        child: Container(
          width: 330,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('round_result'),
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('round_points'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _resultRow(context.tr('team1'), pointsFor(0), Colors.blueAccent),
              const SizedBox(height: 8),
              _resultRow(
                context.tr('team2'),
                pointsFor(1),
                Colors.orangeAccent,
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
              const SizedBox(height: 12),
              Text(
                context.tr('total_points'),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _resultRow(context.tr('team1'), totalFor(0), Colors.blueAccent),
              const SizedBox(height: 8),
              _resultRow(context.tr('team2'), totalFor(1), Colors.orangeAccent),
              if (result['cot_team'] != null) ...[
                const SizedBox(height: 10),
                Text(
                  context.tr('cot_label'),
                  style: const TextStyle(color: AppTheme.gold),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: game.clearRoundResult,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    context.tr('continue'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultRow(String label, int points, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color)),
        Text(
          '$points ${context.tr('match_score')}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  void _showGameOverDialog(int winnerTeam) {
    final myId = context.read<AuthProvider>().user?.id;
    final allPlayers = context.read<RoomProvider>().players;
    final myTeam = allPlayers
        .where((player) => player.user?.id == myId)
        .firstOrNull
        ?.team;
    final isWinner = myTeam == winnerTeam;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text(
          isWinner
              ? '🏆 ${context.tr('you_win')}'
              : '😔 ${context.tr('you_lose')}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isWinner ? AppTheme.gold : Colors.white70,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: Text(context.tr('return_lobby')),
          ),
        ],
      ),
    );
  }
}

class _BidChoiceBadge extends StatelessWidget {
  final String choice;

  const _BidChoiceBadge({required this.choice});

  @override
  Widget build(BuildContext context) {
    final label = choice == 'pass' ? 'passe' : choice;
    final color = switch (choice) {
      'to' => AppTheme.gold,
      'sans' => const Color(0xFFD6A7FF),
      _ => Colors.white70,
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xEE10271C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.3),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _OpponentCardFan extends StatelessWidget {
  final int count;

  const _OpponentCardFan({required this.count});

  @override
  Widget build(BuildContext context) {
    final visibleCount = count.clamp(0, 8);
    return SizedBox(
      width: 78,
      height: 38,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          for (var index = 0; index < visibleCount; index++)
            Positioned(
              left: 23 + (index - (visibleCount - 1) / 2) * 5.2,
              bottom: 0,
              child: Transform.rotate(
                angle: (index - (visibleCount - 1) / 2) * 0.075,
                alignment: Alignment.bottomCenter,
                child: const _MiniCardBack(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniCardBack extends StatelessWidget {
  const _MiniCardBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF242421),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFD6B45F), width: 1),
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, size: 11, color: Color(0xFFD6B45F)),
      ),
    );
  }
}

class _GameRoomBackground extends StatelessWidget {
  const _GameRoomBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06492C), Color(0xFF012A1B)],
        ),
      ),
      child: CustomPaint(painter: _BackgroundPatternPainter()),
    );
  }
}

class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x + size.height, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeltLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.16,
        size.width * 0.76,
        size.height * 0.68,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
