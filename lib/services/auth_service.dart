import 'dart:convert';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.authEndpoint}/signup',
        {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          if (phone != null) 'phone': phone,
        },
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Signup successful',
        'user': response['user'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.authEndpoint}/reset-password',
        {
          'email': email,
          'token': token,
          'newPassword': newPassword,
        },
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Password reset successful',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.authEndpoint}/login',
        {
          'email': email,
          'password': password,
        },
      );

      if (response['token'] != null) {
        await StorageService.saveToken(response['token']);
        await StorageService.saveUserData(jsonEncode(response['user']));

        return {
          'success': true,
          'user': User.fromJson(response['user']),
        };
      } else {
        return {
          'success': false,
          'message': 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.authEndpoint}/forgot-password',
        {'email': email},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Password reset link sent',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<User?> getCurrentUser() async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.authEndpoint}/me',
        requiresAuth: true,
      );

      return User.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  static Future<void> logout() async {
    await StorageService.clearAll();
  }

  static Future<bool> isLoggedIn() async {
    final token = await StorageService.getToken();
    return token != null;
  }
}
