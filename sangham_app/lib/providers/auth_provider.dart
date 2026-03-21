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
    _loadSavedAuth();
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

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(phone, password);

      if (response.containsKey('token')) {
        _token = response['token'];
        final userData = response['user'];
        _user = UserModel.fromJson(userData);

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
    } catch (e) {
      _error = 'Connection error. Check your network.';
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
    } catch (e) {
      _error = 'Connection error. Check your network.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _user = null;
    _token = null;
    notifyListeners();
  }
}
