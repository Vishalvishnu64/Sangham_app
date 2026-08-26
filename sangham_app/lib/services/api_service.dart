import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

class ApiService {
  static String get baseUrl => AppConstants.baseUrl;

  /// Invoked when any authenticated endpoint answers 401.
  /// AuthProvider registers a handler that clears the local session.
  static void Function()? onUnauthorized;

  static const Duration _timeout = Duration(seconds: 20);

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Single entry point for all requests: applies timeouts, validates status
  /// codes, surfaces server messages through [ApiException] and triggers
  /// [onUnauthorized] on session expiry.
  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (requiresAuth) headers.addAll(await _headers());

    http.Response response;
    try {
      Future<http.Response> future;
      if (method == 'GET') {
        future = http.get(uri, headers: headers);
      } else if (method == 'POST') {
        future = http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      } else if (method == 'PUT') {
        future = http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
      } else if (method == 'DELETE') {
        future = http.delete(uri, headers: headers);
      } else {
        throw ArgumentError('Unsupported HTTP method: $method');
      }
      response = await future.timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
          'Request timed out. Please check your connection and try again.');
    } on SocketException {
      throw ApiException(
          'No internet connection. Please check your network.');
    } on http.ClientException {
      throw ApiException('Network error. Please try again.');
    }

    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      if (response.statusCode >= 500) {
        throw ApiException(
          'Server is temporarily unavailable. Please try again shortly.',
          statusCode: response.statusCode,
        );
      }
      throw ApiException(
        'Unexpected server response.',
        statusCode: response.statusCode,
      );
    }

    String? serverMessage(Map<dynamic, dynamic>? d) =>
        d != null && d['message'] is String ? d['message'] as String : null;

    if (response.statusCode == 401) {
      final msg = serverMessage(data) ?? 'Session expired. Please login again.';
      onUnauthorized?.call();
      throw ApiException(msg, statusCode: 401);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        serverMessage(data) ?? 'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return data;
  }

  // ─── AUTH ──────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String phone, String password) async {
    final data = await _send('POST', '/auth/login',
        body: {'phone': phone, 'password': password}, requiresAuth: false);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> register(String name, String phone, String password) async {
    final data = await _send('POST', '/auth/register',
        body: {'name': name, 'phone': phone, 'password': password},
        requiresAuth: false);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final data = await _send('GET', '/auth/me');
    return Map<String, dynamic>.from(data as Map);
  }

  // ─── MEMBERS ──────────────────────────────────────
  static Future<Map<String, dynamic>> getMembers() async {
    final data = await _send('GET', '/members');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> addMember(String name, String phone, String password) async {
    final data = await _send('POST', '/members',
        body: {'name': name, 'phone': phone, 'password': password});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> updateMember(String id, String name, String phone) async {
    final data = await _send('PUT', '/members/$id',
        body: {'name': name, 'phone': phone});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> deleteMember(String id) async {
    final data = await _send('DELETE', '/members/$id');
    return Map<String, dynamic>.from(data as Map? ?? {});
  }

  // ─── TRANSACTIONS ─────────────────────────────────
  static Future<List<dynamic>> getAllTransactions() async {
    final data = await _send('GET', '/transactions');
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> addBulkContribution(
      double amount, List<String>? memberIds, String note) async {
    final data = await _send('POST', '/transactions/bulk', body: {
      'amount': amount,
      'memberIds': memberIds,
      'note': note,
      'type': 'contribution',
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> addSingleTransaction(
      String userId, double amount, String type, String note) async {
    final data = await _send('POST', '/transactions', body: {
      'userId': userId,
      'amount': amount,
      'type': type,
      'note': note,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getTransactionSummary() async {
    final data = await _send('GET', '/transactions/summary');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getUserTransactions(String userId) async {
    final data = await _send('GET', '/transactions/user/$userId');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getWeeklyStatus() async {
    final data = await _send('GET', '/transactions/weekly-status');
    return Map<String, dynamic>.from(data as Map);
  }

  // ─── ATTENDANCE ───────────────────────────────────
  static Future<Map<String, dynamic>> markBulkAttendance(
      List<Map<String, dynamic>> records, String? date) async {
    final data = await _send('POST', '/attendance/bulk',
        body: {'records': records, 'date': date});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getTodayAttendance() async {
    final data = await _send('GET', '/attendance/today');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getUserAttendance(String userId,
      {int? month, int? year}) async {
    String path = '/attendance/user/$userId';
    if (month != null && year != null) {
      path += '?month=$month&year=$year';
    }
    final data = await _send('GET', path);
    return Map<String, dynamic>.from(data as Map);
  }

  // ─── DASHBOARD ────────────────────────────────────
  static Future<Map<String, dynamic>> getAdminDashboard() async {
    final data = await _send('GET', '/dashboard/admin');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getUserDashboard(String userId) async {
    final data = await _send('GET', '/dashboard/user/$userId');
    return Map<String, dynamic>.from(data as Map);
  }

  // ─── LOANS ──────────────────────────────────────────
  static Future<Map<String, dynamic>> issueLoan(
      String userId, double amount, String note) async {
    final data = await _send('POST', '/loans', body: {
      'userId': userId,
      'amount': amount,
      'note': note,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getAllLoans({String? status}) async {
    String path = '/loans';
    if (status != null) path += '?status=$status';
    final data = await _send('GET', path);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getUserLoans(String userId) async {
    final data = await _send('GET', '/loans/user/$userId');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> repayLoan(
      String loanId, double amount, {String paymentType = 'principal'}) async {
    final data = await _send('POST', '/loans/$loanId/repay',
        body: {'amount': amount, 'paymentType': paymentType});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> getLoanDetails(String loanId) async {
    final data = await _send('GET', '/loans/$loanId/details');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> calculateInterest(String loanId) async {
    final data = await _send('POST', '/loans/$loanId/calculate-interest');
    return Map<String, dynamic>.from(data as Map);
  }
}
