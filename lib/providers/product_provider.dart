import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  List<String> _categories = [];
  bool _loading = false;
  String? _error;

  List<Product> get products => _products;
  List<String> get categories => _categories;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> loadProducts({String? category, String? search}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{};
      if (category != null && category.isNotEmpty) params['category'] = category;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final url = Uri.parse(ApiConfig.productsEndpoint).replace(queryParameters: params);
      final data = await ApiService.get(url.toString());
      final List<dynamic> list = data['products'] ?? data;
      _products = list.map((e) => Product.fromJson(e)).toList();

      // Load categories once
      final cats = await ApiService.get('${ApiConfig.productsEndpoint}/categories');
      _categories = (cats['categories'] as List<dynamic>).cast<String>();
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }
}


