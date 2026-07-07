import 'package:dio/dio.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static String get _base => AppConstants.apiUrl;

  static Future<void> _setAuth() async {
    final token = await StorageService.getToken();
    _dio.options.headers['Authorization'] =
        token != null ? 'Bearer $token' : null;
  }

  static Future<Map<String, dynamic>> _handle(Future<Response> Function() call) async {
    try {
      final res = await call();
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final body = e.response?.data;
      final msg = (body is Map && body['error'] != null)
          ? body['error'] as String
          : _friendlyDioMessage(e);
      throw ApiException(msg, statusCode: e.response?.statusCode);
    } catch (e) {
      throw ApiException('Erreur inattendue : $e');
    }
  }

  static String _friendlyDioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Le serveur ne répond pas. Vérifiez votre connexion.';
      case DioExceptionType.connectionError:
        return 'Impossible de se connecter au serveur.';
      default:
        return 'Erreur réseau (${e.response?.statusCode ?? 'inconnu'}).';
    }
  }

  // Auth
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) =>
      _handle(() => _dio.post('$_base/auth/register',
          data: {'username': username, 'email': email, 'password': password}));

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) =>
      _handle(() => _dio.post('$_base/auth/login',
          data: {'identifier': identifier, 'password': password}));

  static Future<Map<String, dynamic>> getMe() async {
    await _setAuth();
    return _handle(() => _dio.get('$_base/auth/me'));
  }

  // Users
  static Future<Map<String, dynamic>> getUser(int userId) async {
    await _setAuth();
    return _handle(() => _dio.get('$_base/users/$userId'));
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    await _setAuth();
    return _handle(() => _dio.put('$_base/users/profile', data: data));
  }

  static Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    await _setAuth();
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath),
    });
    return _handle(() => _dio.post('$_base/users/avatar', data: formData));
  }

  static Future<Map<String, dynamic>> getLeaderboard() async {
    await _setAuth();
    return _handle(() => _dio.get('$_base/users/leaderboard'));
  }

  // Rooms
  static Future<Map<String, dynamic>> listRooms({String status = 'waiting'}) async {
    await _setAuth();
    return _handle(
        () => _dio.get('$_base/rooms/', queryParameters: {'status': status}));
  }

  static Future<Map<String, dynamic>> createRoom({
    required String name,
    String gameType = 'bilt',
    bool isPrivate = false,
  }) async {
    await _setAuth();
    return _handle(() => _dio.post('$_base/rooms/',
        data: {'name': name, 'game_type': gameType, 'is_private': isPrivate}));
  }

  static Future<Map<String, dynamic>> getRoom(String code) async {
    await _setAuth();
    return _handle(() => _dio.get('$_base/rooms/$code'));
  }

  static Future<Map<String, dynamic>> joinRoom(String code,
      {bool spectator = false}) async {
    await _setAuth();
    return _handle(() => _dio.post('$_base/rooms/$code/join',
        data: {'spectator': spectator}));
  }

  static Future<void> leaveRoom(String code) async {
    await _setAuth();
    await _handle(() => _dio.post('$_base/rooms/$code/leave'));
  }
}
