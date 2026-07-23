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
  final double? turnAvailableAt;
  final List<TrickCard> currentTrick;
  final MgTarget? mgTarget;
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
    this.turnAvailableAt,
    this.currentTrick = const [],
    this.mgTarget,
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
      turnAvailableAt: (json['turn_available_at'] as num?)?.toDouble(),
      currentTrick: trickList,
      mgTarget: json['mg_target'] != null
          ? MgTarget.fromJson(json['mg_target'] as Map<String, dynamic>)
          : null,
      tricksPlayed: json['tricks_played'] ?? 0,
      trickCounts: trickCountsMap,
      status: json['status'] ?? 'bidding',
    );
  }
}

class MgTarget {
  final int position;
  final int team;
  final CardModel card;
  final String leadSuit;

  const MgTarget({
    required this.position,
    required this.team,
    required this.card,
    required this.leadSuit,
  });

  factory MgTarget.fromJson(Map<String, dynamic> json) {
    return MgTarget(
      position: json['position'] as int,
      team: json['team'] as int,
      card: CardModel.fromJson({'suit': json['suit'], 'rank': json['rank']}),
      leadSuit: json['lead_suit'] as String,
    );
  }
}
