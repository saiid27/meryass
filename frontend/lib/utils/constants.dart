/// Network configuration.
///
/// Pass values at build/run time:
///   flutter run --dart-define=API_HOST=http://192.168.1.10:5000
///
/// Defaults:
///   Render production backend → https://meryass.onrender.com
class AppConstants {
  static const String renderHost = 'https://meryass.onrender.com';

  static const String _defaultHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defaultHost.isNotEmpty) return _defaultHost;
    return renderHost;
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
