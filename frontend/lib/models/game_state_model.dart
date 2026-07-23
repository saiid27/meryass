import 'card_model.dart';

class GameStateModel {
  final String roomId;
  final String state;
  final Map<int, int> teamScores;
  final int? dealer;
  final String? mode;
  final String? trumpSuit;
  final int? biddingPlayer;
  final Map<int, String> bidChoices;
  final int? biddingTeam;
  final CardModel? turnedCard;
  final int? currentTurn;
  final List<TrickCard> currentTrick;
  final int tricksPlayed;
  final Map<int, int> trickCounts;
  final String status;

  const GameStateModel({
    required this.roomId,
    required this.state,
    required this.teamScores,
    this.dealer,
    this.mode,
    this.trumpSuit,
    this.biddingPlayer,
    this.bidChoices = const {},
    this.biddingTeam,
    this.turnedCard,
    this.currentTurn,
    this.currentTrick = const [],
    this.tricksPlayed = 0,
    this.trickCounts = const {},
    this.status = 'bidding',
  });

  factory GameStateModel.fromJson(Map<String, dynamic> json) {
    final scores = <int, int>{};
    if (json['team_scores'] is Map) {
      (json['team_scores'] as Map).forEach((k, v) {
        scores[int.parse(k.toString())] = v as int;
      });
    }
    final trickCountsMap = <int, int>{};
    if (json['trick_counts'] is Map) {
      (json['trick_counts'] as Map).forEach((k, v) {
        trickCountsMap[int.parse(k.toString())] = v as int;
      });
    }
    final trickList = <TrickCard>[];
    if (json['current_trick'] is List) {
      for (final t in json['current_trick'] as List) {
        trickList.add(TrickCard.fromJson(t as Map<String, dynamic>));
      }
    }
    final choices = <int, String>{};
    if (json['bid_choices'] is Map) {
      (json['bid_choices'] as Map).forEach((k, v) {
        choices[int.parse(k.toString())] = v.toString();
      });
    }
    return GameStateModel(
      roomId: json['room_id']?.toString() ?? '',
      state: json['state'] ?? '',
      teamScores: scores,
      dealer: json['dealer'],
      mode: json['mode'],
      trumpSuit: json['trump_suit'],
      biddingPlayer: json['bidding_player'],
      bidChoices: choices,
      biddingTeam: json['bidding_team'],
      turnedCard: json['turned_card'] != null
          ? CardModel.fromJson(json['turned_card'] as Map<String, dynamic>)
          : null,
      currentTurn: json['current_turn'],
      currentTrick: trickList,
      tricksPlayed: json['tricks_played'] ?? 0,
      trickCounts: trickCountsMap,
      status: json['status'] ?? 'bidding',
    );
  }
}
