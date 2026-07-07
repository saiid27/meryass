import 'user_model.dart';

class RoomModel {
  final int id;
  final String code;
  final String name;
  final String gameType;
  final String status;
  final UserModel? creator;
  final int playerCount;
  final int spectatorCount;
  final bool isPrivate;

  RoomModel({
    required this.id,
    required this.code,
    required this.name,
    required this.gameType,
    required this.status,
    this.creator,
    this.playerCount = 0,
    this.spectatorCount = 0,
    this.isPrivate = false,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      gameType: json['game_type'] ?? 'bilt',
      status: json['status'] ?? 'waiting',
      creator: json['creator'] != null ? UserModel.fromJson(json['creator']) : null,
      playerCount: json['player_count'] ?? 0,
      spectatorCount: json['spectator_count'] ?? 0,
      isPrivate: json['is_private'] ?? false,
    );
  }
}

class RoomPlayerModel {
  final int id;
  final int roomId;
  final UserModel? user;
  final int? position;
  final int? team;
  final bool isSpectator;
  final bool isReady;

  RoomPlayerModel({
    required this.id,
    required this.roomId,
    this.user,
    this.position,
    this.team,
    this.isSpectator = false,
    this.isReady = false,
  });

  factory RoomPlayerModel.fromJson(Map<String, dynamic> json) {
    return RoomPlayerModel(
      id: json['id'],
      roomId: json['room_id'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      position: json['position'],
      team: json['team'],
      isSpectator: json['is_spectator'] ?? false,
      isReady: json['is_ready'] ?? false,
    );
  }
}
