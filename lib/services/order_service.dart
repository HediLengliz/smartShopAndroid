import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../config/api_config.dart';
import 'api_service.dart';
import 'notification_service.dart';

class OrderService {
  static const String _baseEndpoint = '${ApiConfig.baseUrl}/orders';

  // Get all orders with optional filters
  static Future<List<Order>> getOrders({
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    String? search,
    String? status,
    bool? isFavorite,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      if (isFavorite != null) {
        queryParams['isFavorite'] = isFavorite.toString();
      }

      final uri = Uri.parse(_baseEndpoint).replace(queryParameters: queryParams);
      final response = await ApiService.get(uri.toString(), requiresAuth: true);

      final List<dynamic> ordersJson = response['orders'] as List<dynamic>;
      return ordersJson.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('OrderService.getOrders error: $e');
      throw Exception('Failed to fetch orders: $e');
    }
  }

  // Get a specific order by ID
  static Future<Order> getOrderById(int orderId) async {
    try {
      final response = await ApiService.get(
        '$_baseEndpoint/$orderId',
        requiresAuth: true,
      );

      return Order.fromJson(response['order'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('OrderService.getOrderById error: $e');
      throw Exception('Failed to fetch order details: $e');
    }
  }

  // Get favorite orders
  static Future<List<Order>> getFavoriteOrders() async {
    try {
      final response = await ApiService.get(
        '$_baseEndpoint/favorites/list',
        requiresAuth: true,
      );

      final List<dynamic> ordersJson = response['orders'] as List<dynamic>;
      return ordersJson.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('OrderService.getFavoriteOrders error: $e');
      throw Exception('Failed to fetch favorite orders: $e');
    }
  }

  // Toggle favorite status
  static Future<void> toggleFavorite(int orderId, bool isFavorite) async {
    try {
      await ApiService.patch(
        '$_baseEndpoint/$orderId/favorite',
        {'isFavorite': isFavorite},
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('OrderService.toggleFavorite error: $e');
      throw Exception('Failed to update favorite status: $e');
    }
  }

  // Delete an order
  static Future<void> deleteOrder(int orderId) async {
    try {
      await ApiService.delete(
        '$_baseEndpoint/$orderId',
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('OrderService.deleteOrder error: $e');
      throw Exception('Failed to delete order: $e');
    }
  }

  // Notify about order status change (call this when order status changes are detected)
  static Future<void> notifyOrderStatusChange(int orderId, String newStatus) async {
    try {
      await NotificationService.notifyOrderStatusChanged(orderId, newStatus);
    } catch (e) {
      debugPrint('OrderService.notifyOrderStatusChange error: $e');
    }
  }
}

