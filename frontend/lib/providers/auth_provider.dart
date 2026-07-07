import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _loading = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _loading;
  bool get isAuthenticated => _user != null && _token != null;

  Future<void> tryAutoLogin() async {
    final token = await StorageService.getToken();
    if (token == null) return;
    _token = token;
    try {
      final data = await ApiService.getMe();
      _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      SocketService.connect();
      notifyListeners();
    } catch (_) {
      await StorageService.deleteToken();
      _token = null;
    }
  }

  Future<void> register(String username, String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.register(
          username: username, email: email, password: password);
      await _handleAuthResponse(data);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String identifier, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.login(identifier: identifier, password: password);
      await _handleAuthResponse(data);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    _token = data['token'] as String;
    _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await StorageService.saveToken(_token!);
    SocketService.connect();
    notifyListeners();
  }

  Future<void> logout() async {
    SocketService.disconnect();
    await StorageService.deleteToken();
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final data = await ApiService.getMe();
    _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  void updateUser(UserModel updated) {
    _user = updated;
    notifyListeners();
  }
}
