import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class RoomProvider extends ChangeNotifier {
  List<RoomModel> _rooms = [];
  RoomModel? _currentRoom;
  List<RoomPlayerModel> _players = [];
  bool _loading = false;
  String? _error;

  List<RoomModel> get rooms => _rooms;
  RoomModel? get currentRoom => _currentRoom;
  List<RoomPlayerModel> get players => _players;
  bool get isLoading => _loading;
  String? get error => _error;

  List<RoomPlayerModel> get gamePlayers =>
      _players.where((p) => !p.isSpectator).toList()
        ..sort((a, b) => (a.position ?? 99).compareTo(b.position ?? 99));

  List<RoomPlayerModel> get spectators =>
      _players.where((p) => p.isSpectator).toList();

  Future<void> fetchRooms() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiService.listRooms();
      _rooms = (data['rooms'] as List)
          .map((r) => RoomModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<RoomModel?> createRoom(
    String name, {
    String gameType = 'bilt',
    String scoringMode = 'zero',
    bool isPrivate = false,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.createRoom(
        name: name,
        gameType: gameType,
        scoringMode: scoringMode,
        isPrivate: isPrivate,
      );
      final room = RoomModel.fromJson(data['room'] as Map<String, dynamic>);
      _currentRoom = room;
      notifyListeners();
      return room;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> joinRoom(String code, {bool spectator = false}) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.joinRoom(code, spectator: spectator);
      _currentRoom = RoomModel.fromJson(data['room'] as Map<String, dynamic>);
      await loadRoomPlayers(code);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadRoomPlayers(String code) async {
    final data = await ApiService.getRoom(code);
    _currentRoom = RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    _players = (data['players'] as List)
        .map((p) => RoomPlayerModel.fromJson(p as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  void updatePlayersFromSocket(List<dynamic> playersData) {
    _players = playersData
        .map((p) => RoomPlayerModel.fromJson(p as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  void updateRoomState(Map<String, dynamic> data) {
    _currentRoom = RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    updatePlayersFromSocket(data['players'] as List);
  }

  Future<void> benchPlayer(String code, int memberId) async {
    final data = await ApiService.benchRoomPlayer(code, memberId);
    updateRoomState(data);
  }

  Future<void> fillWithBots(String code) async {
    final data = await ApiService.fillRoomWithBots(code);
    updateRoomState(data);
  }

  Future<void> assignSeat(String code, int position, int memberId) async {
    final data = await ApiService.assignRoomSeat(
      code: code,
      position: position,
      memberId: memberId,
    );
    updateRoomState(data);
  }

  void setupSocketListeners(String token, String roomCode) {
    SocketService.on('room:state', (data) {
      _currentRoom = RoomModel.fromJson(data['room'] as Map<String, dynamic>);
      updatePlayersFromSocket(data['players'] as List);
    });

    SocketService.on('room:player_ready', (data) {
      updatePlayersFromSocket(data['players'] as List);
    });

    SocketService.on('room:player_left', (data) {
      final userId = data['user_id'];
      _players.removeWhere((p) => p.user?.id == userId);
      notifyListeners();
    });
  }

  void joinRoomSocket(String token, String roomCode) {
    SocketService.joinRoom(token, roomCode);
  }

  void setReady(String token, String roomCode) {
    SocketService.setReady(token, roomCode);
  }

  void leaveCurrentRoom(String token, String roomCode) {
    SocketService.leaveRoom(token, roomCode);
    SocketService.off('room:state');
    SocketService.off('room:player_ready');
    SocketService.off('room:player_left');
    _currentRoom = null;
    _players = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
