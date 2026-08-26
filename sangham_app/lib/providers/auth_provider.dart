import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isAdmin => _user?.role == 'admin';

  AuthProvider() {
    // Constructor does not load auth automatically anymore. We will call init() explicitly.
    // React to server-side session rejection (expired/revoked token) globally.
    ApiService.onUnauthorized = _handleUnauthorized;
  }

  Future<void> init() async {
    await _loadSavedAuth();
    if (_token != null) {
      // Validate the stored token against the server. If the network is slow
      // or unreachable we keep the cached session rather than blocking the
      // splash screen indefinitely; subsequent API calls will surface errors.
      try {
        await _validateSession().timeout(const Duration(seconds: 10));
      } catch (_) {
        // Validation unavailable (offline/slow) – proceed with cached auth.
      }
    }
  }

  Future<void> _loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName');
    final userPhone = prefs.getString('userPhone');
    final userRole = prefs.getString('userRole');

    if (_token != null && userId != null) {
      _user = UserModel(
        id: userId,
        name: userName ?? '',
        phone: userPhone ?? '',
        role: userRole ?? 'user',
      );
      notifyListeners();
    }
  }

  /// Re-checks the saved token with GET /auth/me and refreshes profile data.
  Future<void> _validateSession() async {
    try {
      final response = await ApiService.getCurrentUser();
      final userData = response['user'];
      if (userData is Map) {
        _user = UserModel.fromJson(Map<String, dynamic>.from(userData));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _user!.id);
        await prefs.setString('userName', _user!.name);
        await prefs.setString('userPhone', _user!.phone);
        await prefs.setString('userRole', _user!.role);
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.isAuthError) {
        // Session was already cleared by the onUnauthorized hook.
        return;
      }
      // Server/network problem: keep cached session for offline start.
    } catch (_) {
      // Keep cached session; do not log users out for transient failures.
    }
  }

  void _handleUnauthorized() {
    if (_token == null && _user == null) return;
    _clearLocalAuth();
  }

  Future<void> _clearLocalAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userPhone');
    await prefs.remove('userRole');
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(phone, password);

      if (response.containsKey('token')) {
        _token = response['token'] as String?;
        final userData = response['user'];
        _user = UserModel.fromJson(Map<String, dynamic>.from(userData));

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('userId', _user!.id);
        await prefs.setString('userName', _user!.name);
        await prefs.setString('userPhone', _user!.phone);
        await prefs.setString('userRole', _user!.role);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.register(name, phone, password);

      if (response.containsKey('user')) {
        // Registration successful
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Something went wrong. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _clearLocalAuth();
  }
}
