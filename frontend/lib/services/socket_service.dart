import 'package:socket_io_client/socket_io_client.dart' as sio;
import '../utils/constants.dart';

class SocketService {
  static sio.Socket? _socket;

  static sio.Socket get socket {
    _socket ??= sio.io(
      AppConstants.socketUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    return _socket!;
  }

  static void connect() {
    if (!socket.connected) socket.connect();
  }

  static void disconnect() {
    socket.disconnect();
  }

  static bool get isConnected => socket.connected;

  // Room events
  static void joinRoom(String token, String roomCode) =>
      socket.emit('room:join', {'token': token, 'room_code': roomCode});

  static void leaveRoom(String token, String roomCode) =>
      socket.emit('room:leave', {'token': token, 'room_code': roomCode});

  static void setReady(String token, String roomCode) =>
      socket.emit('room:ready', {'token': token, 'room_code': roomCode});

  // Game events
  static void bid(
    String token,
    String roomCode,
    String action, {
    String? suit,
  }) {
    final payload = {'token': token, 'room_code': roomCode, 'action': action};
    if (suit != null) payload['suit'] = suit;
    socket.emit('game:bid', payload);
  }

  static void playCard(
    String token,
    String roomCode,
    String suit,
    String rank,
  ) {
    socket.emit('game:play_card', {
      'token': token,
      'room_code': roomCode,
      'suit': suit,
      'rank': rank,
    });
  }

  static void declare(String token, String roomCode) =>
      socket.emit('game:declare', {'token': token, 'room_code': roomCode});

  static void mg(String token, String roomCode) =>
      socket.emit('game:mg', {'token': token, 'room_code': roomCode});

  static void nextRound(String token, String roomCode) =>
      socket.emit('game:next_round', {'token': token, 'room_code': roomCode});

  // Listener management
  static void on(String event, void Function(dynamic) handler) =>
      socket.on(event, handler);

  static void off(String event) => socket.off(event);
}
