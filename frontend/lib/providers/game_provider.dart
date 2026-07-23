import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/game_state_model.dart';
import '../services/socket_service.dart';

class GameProvider extends ChangeNotifier {
  GameStateModel? _gameState;
  List<CardModel> _myHand = [];
  int? _myPosition;
  Map<String, dynamic>? _roundResult;
  int? _gameWinner;
  List<Map<String, dynamic>> _recentDeclarations = [];
  bool _gameStarted = false;
  bool _listenersAttached = false;

  GameStateModel? get gameState => _gameState;
  List<CardModel> get myHand => _myHand;
  int? get myPosition => _myPosition;
  Map<String, dynamic>? get roundResult => _roundResult;
  int? get gameWinner => _gameWinner;
  List<Map<String, dynamic>> get recentDeclarations => _recentDeclarations;
  bool get gameStarted => _gameStarted;

  bool get isMyTurn => _gameState?.currentTurn == _myPosition;
  bool get isMyBidTurn =>
      _gameState?.status == 'bidding' &&
      _myPosition != null &&
      _gameState?.biddingPlayer == _myPosition &&
      !(_gameState?.bidChoices.containsKey(_myPosition) ?? false);

  void setupSocketListeners(String token, String roomCode) {
    // Guard: never attach twice
    if (_listenersAttached) return;
    _listenersAttached = true;

    SocketService.on('game:started', (dynamic data) {
      final state = (data as Map<String, dynamic>)['state'];
      if (state != null) {
        _gameState = GameStateModel.fromJson(state as Map<String, dynamic>);
        _roundResult = null;
        _gameWinner = null;
        _gameStarted = true; // triggers navigation in RoomScreen
        notifyListeners();
      }
    });

    SocketService.on('game:hand', (dynamic data) {
      final d = data as Map<String, dynamic>;
      _myPosition = d['position'] as int;
      _myHand = (d['hand'] as List)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList();
      notifyListeners();
    });

    SocketService.on('game:state_update', (dynamic data) {
      final state = (data as Map<String, dynamic>)['state'];
      if (state != null) {
        _gameState = GameStateModel.fromJson(state as Map<String, dynamic>);
        notifyListeners();
      }
    });

    SocketService.on('game:round_result', (dynamic data) {
      final d = data as Map<String, dynamic>;
      _roundResult = d['result'] as Map<String, dynamic>?;
      _gameWinner = d['game_winner'] as int?;
      notifyListeners();
    });

    SocketService.on('game:new_round', (dynamic data) {
      final state = (data as Map<String, dynamic>)['state'];
      if (state != null) {
        _gameState = GameStateModel.fromJson(state as Map<String, dynamic>);
        _roundResult = null;
        notifyListeners();
      }
    });

    SocketService.on('game:declarations', (dynamic data) {
      _recentDeclarations.add(data as Map<String, dynamic>);
      notifyListeners();
    });
  }

  void bid(String token, String roomCode, String action, {String? suit}) =>
      SocketService.bid(token, roomCode, action, suit: suit);

  void playCard(String token, String roomCode, CardModel card) =>
      SocketService.playCard(token, roomCode, card.suit, card.rank);

  void declare(String token, String roomCode) =>
      SocketService.declare(token, roomCode);

  void removeSocketListeners() {
    if (!_listenersAttached) return;
    SocketService.off('game:started');
    SocketService.off('game:hand');
    SocketService.off('game:state_update');
    SocketService.off('game:round_result');
    SocketService.off('game:new_round');
    SocketService.off('game:declarations');
    _listenersAttached = false;
  }

  void reset() {
    removeSocketListeners();
    _gameState = null;
    _myHand = [];
    _myPosition = null;
    _roundResult = null;
    _gameWinner = null;
    _recentDeclarations = [];
    _gameStarted = false;
    notifyListeners();
  }
}
