import 'dart:convert';
import 'package:smart_shop/services/storage_service.dart';

import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../models/product.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class ShoppingListService {
  // Get all shopping lists for the user
  static Future<List<ShoppingList>> getShoppingLists() async {
    try {
      final response = await ApiService.get(
        ApiConfig.shoppingListsEndpoint,
        requiresAuth: true, // Add this
      );
      final listsData = response['lists'] as List<dynamic>;
      return listsData.map((list) => ShoppingList.fromJson(list as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error fetching shopping lists: $e');
      rethrow;
    }
  }

  // Get a specific shopping list with its items
  static Future<Map<String, dynamic>> getShoppingList(int listId) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.shoppingListsEndpoint}/$listId',
        requiresAuth: true, // Add this
      );
      return {
        'list': ShoppingList.fromJson(response['list'] as Map<String, dynamic>),
        'items': (response['items'] as List<dynamic>)
            .map((item) => ShoppingListItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      };
    } catch (e) {
      print('Error fetching shopping list: $e');
      rethrow;
    }
  }

  // Create a new shopping list
  static Future<ShoppingList> createShoppingList(String name) async {
    try {
      final response = await ApiService.post(
        ApiConfig.shoppingListsEndpoint,
        {'name': name},
        requiresAuth: true, // Add this
      );
      return ShoppingList.fromJson(response['list'] as Map<String, dynamic>);
    } catch (e) {
      print('Error creating shopping list: $e');
      rethrow;
    }
  }

  // Update a shopping list
  static Future<ShoppingList> updateShoppingList(int listId, String name) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.shoppingListsEndpoint}/$listId',
        {'name': name},
        requiresAuth: true, // Add this
      );
      return ShoppingList.fromJson(response['list'] as Map<String, dynamic>);
    } catch (e) {
      print('Error updating shopping list: $e');
      rethrow;
    }
  }

  // Delete a shopping list
  static Future<void> deleteShoppingList(int listId) async {
    try {
      await ApiService.delete(
        '${ApiConfig.shoppingListsEndpoint}/$listId',
        requiresAuth: true, // Add this
      );
    } catch (e) {
      print('Error deleting shopping list: $e');
      rethrow;
    }
  }

  // Add item to shopping list
  // Add item to shopping list
  static Future<ShoppingListItem> addItemToList(
      int listId,
      int productId, {
        int quantity = 1,
      }) async {
    try {
      print('🛒 Adding item to list $listId, product: $productId, quantity: $quantity');

      final response = await ApiService.post(
        '${ApiConfig.shoppingListsEndpoint}/$listId/items',
        {
          'productId': productId,
          'quantity': quantity,
        },
        requiresAuth: true,
      );

      print('📦 API Response for add item: $response');

      return ShoppingListItem.fromJson(response['item'] as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error adding item to shopping list: $e');
      rethrow;
    }
  }

  // Update shopping list item
  static Future<ShoppingListItem> updateListItem(
      int listId,
      int itemId, {
        int? quantity,
        bool? isPurchased,
        int? position,
      }) async {
    try {
      final Map<String, dynamic> data = {};
      if (quantity != null) data['quantity'] = quantity;
      if (isPurchased != null) data['isPurchased'] = isPurchased;
      if (position != null) data['position'] = position;

      final response = await ApiService.put(
        '${ApiConfig.shoppingListsEndpoint}/$listId/items/$itemId',
        data,
        requiresAuth: true, // Add this
      );
      return ShoppingListItem.fromJson(response['item'] as Map<String, dynamic>);
    } catch (e) {
      print('Error updating shopping list item: $e');
      rethrow;
    }
  }

  // Remove item from shopping list
  static Future<void> removeItemFromList(int listId, int itemId) async {
    try {
      await ApiService.delete(
        '${ApiConfig.shoppingListsEndpoint}/$listId/items/$itemId',
        requiresAuth: true, // Add this
      );
    } catch (e) {
      print('Error removing item from shopping list: $e');
      rethrow;
    }
  }

  // Search products for adding to list
  static Future<List<Product>> searchProducts(String query) async {
    try {
      // Product search might not require auth, but add it if it does
      final response = await ApiService.get(
        '${ApiConfig.productsEndpoint}?search=$query',
        requiresAuth: false, // Products are usually public
      );
      final productsData = response['products'] as List<dynamic>;
      return productsData.map((product) => Product.fromJson(product as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error searching products: $e');
      rethrow;
    }
  }

  // Debug method to check token
  static Future<void> debugToken() async {
    try {
      final token = await StorageService.getToken();
      print('🔐 Token exists: ${token != null}');
      if (token != null) {
        print('🔐 Token length: ${token.length}');
        print('🔐 Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      } else {
        print('🔐 No token found in storage');
      }
    } catch (e) {
      print('🔐 Error checking token: $e');
    }
  }
}