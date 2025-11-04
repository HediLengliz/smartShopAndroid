import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';
import '../models/product.dart';

class ApiService {
  static Future<Map<String, String>> _getHeaders({bool includeAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await StorageService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<dynamic> get(String endpoint, {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(includeAuth: requiresAuth);
      final response = await http
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body,
      {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(includeAuth: requiresAuth);
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body,
      {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(includeAuth: requiresAuth);
      final response = await http
          .put(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<dynamic> patch(String endpoint, Map<String, dynamic> body,
      {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(includeAuth: requiresAuth);
      final response = await http
          .patch(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<dynamic> delete(String endpoint, {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(includeAuth: requiresAuth);
      final response = await http
          .delete(Uri.parse(endpoint), headers: headers)
          .timeout(ApiConfig.timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else if (response.statusCode == 403) {
      throw Exception('Forbidden - Access denied');
    } else if (response.statusCode == 404) {
      throw Exception('Not found');
    } else if (response.statusCode >= 500) {
      throw Exception('Server error - Please try again later');
    } else {
      final errorBody = jsonDecode(response.body);
      final errorMessage = errorBody['error'] ?? errorBody['message'] ?? 'Request failed';
      throw Exception(errorMessage);
    }
  }
  // Méthode spécifique pour récupérer les produits
  static Future<List<Product>> fetchProducts({String? category, String? search}) async {
    try {
      final queryParameters = <String, String>{};
      if (category != null) queryParameters['category'] = category;
      if (search != null) queryParameters['search'] = search;

      // Construire l'URL avec query params
      Uri uri = Uri.parse(ApiConfig.productsEndpoint).replace(queryParameters: queryParameters);

      final data = await get(uri.toString(), requiresAuth: false);

      final productsJson = data['products'] as List<dynamic>;
      return productsJson.map((json) => Product.fromJson(json)).toList();
    } catch (e) {
      print('ApiService.fetchProducts error: $e');
      throw e;
    }
  }
  // ✅ Fetch categories from API
  static Future<List<String>> fetchCategories() async {
    try {
      final data = await get("${ApiConfig.productsEndpoint}/categories", requiresAuth: false);

      if (data == null) return [];

      final cats = (data['categories'] as List<dynamic>? ) ?? [];

      return cats.map((c) => c.toString()).toList();
    } catch (e) {
      print("ApiService.fetchCategories error: $e");
      rethrow;
    }
  }

}

