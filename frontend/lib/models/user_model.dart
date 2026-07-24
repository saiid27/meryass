class UserModel {
  final int id;
  final String username;
  final String? email;
  final String? phone;
  final String? avatar;
  final int wins;
  final int losses;
  final int roundsPlayed;
  final int totalPoints;
  final int rank;
  final bool isOnline;
  final bool isBot;

  UserModel({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    this.avatar,
    this.wins = 0,
    this.losses = 0,
    this.roundsPlayed = 0,
    this.totalPoints = 0,
    this.rank = 0,
    this.isOnline = false,
    this.isBot = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phone: json['phone'],
      avatar: json['avatar'],
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      roundsPlayed: json['rounds_played'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
      rank: json['rank'] ?? 0,
      isOnline: json['is_online'] ?? false,
      isBot: json['is_bot'] ?? false,
    );
  }

  int get gamesPlayed => wins + losses;
  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;
}
