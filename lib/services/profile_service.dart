import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/dashboard.dart';
import 'api_service.dart';

class ProfileService {
  static const String _profileEndpoint = '${ApiConfig.baseUrl}/profile';

  // Get profile statistics
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await ApiService.get(
        '$_profileEndpoint/stats',
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      debugPrint('ProfileService.getStats error: $e');
      throw Exception('Failed to fetch profile stats: $e');
    }
  }

  // Get dashboard data
  static Future<DashboardData> getDashboard() async {
    try {
      final response = await ApiService.get(
        '$_profileEndpoint/dashboard',
        requiresAuth: true,
      );
      return DashboardData.fromJson(response);
    } catch (e) {
      debugPrint('ProfileService.getDashboard error: $e');
      throw Exception('Failed to fetch dashboard data: $e');
    }
  }

  // Upload profile picture
  static Future<String> uploadProfilePicture(Uint8List imageBytes) async {
    try {
      // Convert bytes to base64
      final base64Image = base64Encode(imageBytes);
      final imageBase64 = 'data:image/jpeg;base64,$base64Image';

      final response = await ApiService.post(
        '$_profileEndpoint/upload-picture',
        {'imageBase64': imageBase64},
        requiresAuth: true,
      );

      return response['imageUrl'] as String;
    } catch (e) {
      debugPrint('ProfileService.uploadProfilePicture error: $e');
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // Update profile
  static Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? profilePictureUrl,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (firstName != null) data['firstName'] = firstName;
      if (lastName != null) data['lastName'] = lastName;
      if (phone != null) data['phone'] = phone;
      if (profilePictureUrl != null) data['profilePictureUrl'] = profilePictureUrl;

      final response = await ApiService.put(
        _profileEndpoint,
        data,
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      debugPrint('ProfileService.updateProfile error: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // Update password
  static Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await ApiService.put(
        '$_profileEndpoint/password',
        {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('ProfileService.updatePassword error: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  // Delete account
  static Future<void> deleteAccount() async {
    try {
      await ApiService.delete(
        '$_profileEndpoint/account',
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('ProfileService.deleteAccount error: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  // Get addresses
  static Future<List<dynamic>> getAddresses() async {
    try {
      final response = await ApiService.get(
        '$_profileEndpoint/addresses',
        requiresAuth: true,
      );
      return response['addresses'] as List<dynamic>;
    } catch (e) {
      debugPrint('ProfileService.getAddresses error: $e');
      throw Exception('Failed to fetch addresses: $e');
    }
  }

  // Get product analytics (most/least bought products)
  static Future<Map<String, dynamic>> getProductAnalytics({
    int limit = 10,
    String sortBy = 'most',
  }) async {
    try {
      final uri = Uri.parse('$_profileEndpoint/analytics/products')
          .replace(queryParameters: {
        'limit': limit.toString(),
        'sortBy': sortBy,
      });

      final response = await ApiService.get(
        uri.toString(),
        requiresAuth: true,
      );
      return response;
    } catch (e) {
      debugPrint('ProfileService.getProductAnalytics error: $e');
      throw Exception('Failed to fetch product analytics: $e');
    }
  }

  // Get latest orders for profile
  static Future<List<dynamic>> getLatestOrders({int limit = 5}) async {
    try {
      final uri = Uri.parse('$_profileEndpoint/latest-orders')
          .replace(queryParameters: {
        'limit': limit.toString(),
      });

      final response = await ApiService.get(
        uri.toString(),
        requiresAuth: true,
      );
      return response['orders'] as List<dynamic>;
    } catch (e) {
      debugPrint('ProfileService.getLatestOrders error: $e');
      throw Exception('Failed to fetch latest orders: $e');
    }
  }
}

