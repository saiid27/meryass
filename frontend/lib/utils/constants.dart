/// Network configuration.
///
/// Pass values at build/run time:
///   flutter run --dart-define=API_HOST=http://192.168.1.10:5000
///
/// Defaults:
///   Android emulator → 10.0.2.2:5000
///   iOS simulator / real device / web → localhost:5000
class AppConstants {
  static const String _defaultHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defaultHost.isNotEmpty) return _defaultHost;
    // Android emulator uses 10.0.2.2 to reach the host loopback
    return 'http://localhost:5000';
  }

  static String get apiUrl => '$baseUrl/api';
  static String get socketUrl => baseUrl;

  static String avatarUrl(String filename) => '$apiUrl/users/avatars/$filename';

  static const int matchWinScore = 152;
}

class Suit {
  static const String hearts = 'hearts';
  static const String diamonds = 'diamonds';
  static const String clubs = 'clubs';
  static const String spades = 'spades';

  static String symbol(String suit) {
    switch (suit) {
      case hearts:
        return '♥';
      case diamonds:
        return '♦';
      case clubs:
        return '♣';
      case spades:
        return '♠';
      default:
        return suit;
    }
  }

  static bool isRed(String suit) => suit == hearts || suit == diamonds;
}
