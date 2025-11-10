import '../models/product.dart';
import 'api_service.dart';
import '../config/api_config.dart';
import 'database_service.dart';

class ProductService {
  // Récupère les produits depuis le backend
  static Future<List<Product>> fetchProducts({String? category, String? search}) async {
    final queryParameters = <String, String>{};
    if (category != null) queryParameters['category'] = category;
    if (search != null) queryParameters['search'] = search;

    final queryString = queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&');
    final url = '${ApiConfig.productsEndpoint}${queryString.isNotEmpty ? '?$queryString' : ''}';

    final response = await ApiService.get(url);
    final productsData = response['products'] as List<dynamic>;

    final products = productsData.map((e) => Product.fromJson(e)).toList();

    // Stockage local
    await DatabaseService().saveProducts(products);

    return products;
  }
}
