class CardModel {
  final String suit;
  final String rank;

  const CardModel({required this.suit, required this.rank});

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(suit: json['suit'], rank: json['rank']);
  }

  Map<String, dynamic> toJson() => {'suit': suit, 'rank': rank};

  bool get isRed => suit == 'hearts' || suit == 'diamonds';

  String get suitSymbol {
    switch (suit) {
      case 'hearts': return '♥';
      case 'diamonds': return '♦';
      case 'clubs': return '♣';
      case 'spades': return '♠';
      default: return suit;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CardModel && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;

  @override
  String toString() => '$rank$suitSymbol';
}

class TrickCard {
  final int position;
  final CardModel card;

  TrickCard({required this.position, required this.card});

  factory TrickCard.fromJson(Map<String, dynamic> json) {
    return TrickCard(
      position: json['position'],
      card: CardModel(suit: json['suit'], rank: json['rank']),
    );
  }
}
