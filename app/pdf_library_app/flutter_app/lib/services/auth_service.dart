import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService({required this.baseUrl});
  final String baseUrl;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'access_token';
  Future<String?> get token => _storage.read(key: _tokenKey);

  Future<bool> isLoggedIn() async {
    final t = await token;
    if (t == null || t.isEmpty) return false;
    try {
      final response = await http.get(Uri.parse('$baseUrl/auth/me'), headers: {'Authorization': 'Bearer $t'}).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return true;
    } catch (_) {}
    await logout();
    return false;
  }

  Future<void> register({required String email, required String password, String? displayName}) async {
    final response = await http.post(Uri.parse('$baseUrl/auth/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password, 'display_name': displayName})).timeout(const Duration(seconds: 12));
    if (response.statusCode != 201) throw Exception(_extractError(response));
    await login(email: email, password: password);
  }

  Future<void> login({required String email, required String password}) async {
    final response = await http.post(Uri.parse('$baseUrl/auth/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password})).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception(_extractError(response));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'];
    if (token is! String || token.isEmpty) throw Exception('Le serveur a renvoyé une session invalide.');
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> logout() => _storage.delete(key: _tokenKey);

  Future<Map<String, String>> authHeaders() async {
    final t = await token;
    return t == null ? {} : {'Authorization': 'Bearer $t'};
  }

  String _extractError(http.Response response) {
    try { final data = jsonDecode(response.body); return (data['detail'] ?? 'Erreur (${response.statusCode}).').toString(); }
    catch (_) { return 'Erreur réseau (${response.statusCode}).'; }
  }
}
