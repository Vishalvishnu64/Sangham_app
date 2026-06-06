import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  static String get baseUrl => AppConstants.baseUrl;

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

  // ─── AUTH ──────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> register(String name, String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  // ─── MEMBERS ──────────────────────────────────────
  static Future<Map<String, dynamic>> getMembers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/members'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addMember(String name, String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/members'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'phone': phone, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateMember(String id, String name, String phone) async {
    final response = await http.put(
      Uri.parse('$baseUrl/members/$id'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'phone': phone}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteMember(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/members/$id'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  // ─── TRANSACTIONS ─────────────────────────────────
  static Future<List<dynamic>> getAllTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addBulkContribution(
      double amount, List<String>? memberIds, String note) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/bulk'),
      headers: await _headers(),
      body: jsonEncode({
        'amount': amount,
        'memberIds': memberIds,
        'note': note,
        'type': 'contribution',
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addSingleTransaction(
      String userId, double amount, String type, String note) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: await _headers(),
      body: jsonEncode({
        'userId': userId,
        'amount': amount,
        'type': type,
        'note': note,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getTransactionSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/summary'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserTransactions(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/user/$userId'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getWeeklyStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/weekly-status'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  // ─── ATTENDANCE ───────────────────────────────────
  static Future<Map<String, dynamic>> markBulkAttendance(
      List<Map<String, dynamic>> records, String? date) async {
    final response = await http.post(
      Uri.parse('$baseUrl/attendance/bulk'),
      headers: await _headers(),
      body: jsonEncode({'records': records, 'date': date}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getTodayAttendance() async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/today'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserAttendance(
      String userId, {int? month, int? year}) async {
    String url = '$baseUrl/attendance/user/$userId';
    if (month != null && year != null) {
      url += '?month=$month&year=$year';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  // ─── DASHBOARD ────────────────────────────────────
  static Future<Map<String, dynamic>> getAdminDashboard() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/admin'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserDashboard(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/user/$userId'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  // ─── LOANS ──────────────────────────────────────────
  static Future<Map<String, dynamic>> issueLoan(
      String userId, double amount, String note) async {
    final response = await http.post(
      Uri.parse('$baseUrl/loans'),
      headers: await _headers(),
      body: jsonEncode({
        'userId': userId,
        'amount': amount,
        'note': note,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAllLoans({String? status}) async {
    String url = '$baseUrl/loans';
    if (status != null) url += '?status=$status';
    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserLoans(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/loans/user/$userId'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> repayLoan(
      String loanId, double amount, {String paymentType = 'principal'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/loans/$loanId/repay'),
      headers: await _headers(),
      body: jsonEncode({'amount': amount, 'paymentType': paymentType}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getLoanDetails(String loanId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/loans/$loanId/details'),
      headers: await _headers(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> calculateInterest(String loanId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/loans/$loanId/calculate-interest'),
      headers: await _headers(),
      body: jsonEncode({}),
    );
    return jsonDecode(response.body);
  }
}
