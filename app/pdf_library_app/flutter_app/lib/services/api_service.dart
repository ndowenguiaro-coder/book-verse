import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/book_item.dart';
import 'auth_service.dart';

/// Centralise tous les appels réseau vers le backend FastAPI.
/// Les favoris et la progression de lecture nécessitent désormais un
/// utilisateur connecté (JWT) au lieu d'un simple device_id non sécurisé.
class ApiService {
  ApiService({required this.baseUrl, required this.authService});

  final String baseUrl;
  final AuthService authService;

  Future<List<BookItem>> fetchBooks({
    dynamic genreId,
    dynamic categoryId,
    String? search,
    String? sortBy,
  }) async {
    final params = <String, String>{};
    if (genreId != null) params['genre_id'] = '$genreId';
    if (categoryId != null) params['category_id'] = '$categoryId';
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (sortBy != null) params['sort_by'] = sortBy;

    final uri = Uri.parse('$baseUrl/books/').replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les livres (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => BookItem.fromJson(e, baseUrl: baseUrl)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchGenres() async {
    final response = await http.get(Uri.parse('$baseUrl/genres/'));
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les genres.');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/categories/'));
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les catégories.');
    }
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  Future<Uint8List> downloadPdfBytes(int bookId) async {
    final response = await http.get(Uri.parse('$baseUrl/books/$bookId/download'));
    if (response.statusCode != 200) {
      throw Exception('Impossible de télécharger le PDF.');
    }
    return response.bodyBytes;
  }

  Future<void> registerView(int bookId) async {
    await http.patch(Uri.parse('$baseUrl/books/$bookId/view'));
  }

  Future<void> addFavorite(int bookId) async {
    final headers = await authService.authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/favorites/?book_id=$bookId'),
      headers: headers,
    );
    if (response.statusCode != 201) {
      throw Exception('Impossible d\'ajouter aux favoris (${response.statusCode}).');
    }
  }

  Future<void> removeFavorite(int bookId) async {
    final headers = await authService.authHeaders();
    await http.delete(Uri.parse('$baseUrl/favorites/$bookId'), headers: headers);
  }

  Future<List<int>> fetchFavoriteIds() async {
    if (!await authService.isLoggedIn()) return [];
    final headers = await authService.authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/favorites/'), headers: headers);
    if (response.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(response.body);
    return data.map<int>((e) => e['id'] as int).toList();
  }

  Future<void> saveReadingProgress(int bookId, int currentPage) async {
    if (!await authService.isLoggedIn()) return;
    final headers = await authService.authHeaders();
    headers['Content-Type'] = 'application/json';
    await http.put(
      Uri.parse('$baseUrl/books/$bookId/progress'),
      headers: headers,
      body: jsonEncode({'current_page': currentPage}),
    );
  }

  /// Renvoie la dernière page lue par l'utilisateur pour ce livre, ou null
  /// s'il n'est pas connecté ou n'a jamais ouvert ce livre.
  Future<int?> fetchReadingProgress(int bookId) async {
    if (!await authService.isLoggedIn()) return null;
    final headers = await authService.authHeaders();
    final response = await http.get(Uri.parse('$baseUrl/books/$bookId/progress'), headers: headers);
    if (response.statusCode != 200 || response.body == 'null') return null;
    final data = jsonDecode(response.body);
    return data['current_page'] as int?;
  }
}
