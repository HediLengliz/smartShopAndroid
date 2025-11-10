import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/payment_method.dart';
import 'api_service.dart';

class PaymentService {
  // Get all saved payment methods for the current user
  static Future<List<PaymentMethod>> getPaymentMethods() async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.paymentsEndpoint}/methods',
        requiresAuth: true,
      );

      final paymentMethodsJson = response['paymentMethods'] as List<dynamic>?;
      if (paymentMethodsJson == null) return [];

      return paymentMethodsJson
          .map((json) => PaymentMethod.fromJson(json))
          .toList();
    } catch (e) {
      print('PaymentService.getPaymentMethods error: $e');
      throw Exception('Failed to fetch payment methods: $e');
    }
  }

  // Get setup intent and publishable key for StripeY
  static Future<Map<String, String>> getSetupIntent() async {
    try {
      debugPrint('PaymentService: Fetching setup intent...');
      final response = await ApiService.get(
        '${ApiConfig.paymentsEndpoint}/setup-intent',
        requiresAuth: true,
      );

      debugPrint('PaymentService: Setup intent response: $response');

      if (response['clientSecret'] == null || response['publishableKey'] == null) {
        throw Exception('Invalid response: missing clientSecret or publishableKey');
      }

      return {
        'clientSecret': response['clientSecret'] as String,
        'publishableKey': response['publishableKey'] as String,
      };
    } catch (e) {
      debugPrint('PaymentService.getSetupIntent error: $e');
      rethrow;
    }
  }

  // Save a payment method (from Stripe payment method ID)
  static Future<PaymentMethod> savePaymentMethod({
    required String paymentMethodId,
    bool isDefault = false,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.paymentsEndpoint}/methods',
        {
          'paymentMethodId': paymentMethodId,
          'isDefault': isDefault,
        },
        requiresAuth: true,
      );

      return PaymentMethod.fromJson(response['paymentMethod']);
    } catch (e) {
      print('PaymentService.savePaymentMethod error: $e');
      throw Exception('Failed to save payment method: $e');
    }
  }

  // Delete a payment method
  static Future<void> deletePaymentMethod(int paymentMethodId) async {
    try {
      await ApiService.delete(
        '${ApiConfig.paymentsEndpoint}/methods/$paymentMethodId',
        requiresAuth: true,
      );
    } catch (e) {
      print('PaymentService.deletePaymentMethod error: $e');
      throw Exception('Failed to delete payment method: $e');
    }
  }

  // Set default payment method
  static Future<void> setDefaultPaymentMethod(int paymentMethodId) async {
    try {
      await ApiService.patch(
        '${ApiConfig.paymentsEndpoint}/methods/$paymentMethodId/default',
        {},
        requiresAuth: true,
      );
    } catch (e) {
      print('PaymentService.setDefaultPaymentMethod error: $e');
      throw Exception('Failed to set default payment method: $e');
    }
  }

  // Create payment intent
  static Future<Map<String, dynamic>> createPaymentIntent({
    required double amount,
    String currency = 'usd',
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.paymentsEndpoint}/create-payment-intent',
        {
          'amount': amount,
          'currency': currency,
        },
        requiresAuth: true,
      );

      return {
        'clientSecret': response['clientSecret'] as String,
        'paymentIntentId': response['paymentIntentId'] as String,
      };
    } catch (e) {
      print('PaymentService.createPaymentIntent error: $e');
      throw Exception('Failed to create payment intent: $e');
    }
  }

  // Confirm payment
  static Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
    int? orderId,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.paymentsEndpoint}/confirm-payment',
        {
          'paymentIntentId': paymentIntentId,
          if (orderId != null) 'orderId': orderId,
        },
        requiresAuth: true,
      );

      return response;
    } catch (e) {
      print('PaymentService.confirmPayment error: $e');
      throw Exception('Failed to confirm payment: $e');
    }
  }

  // Complete checkout and receive receipt
  static Future<Map<String, dynamic>> checkout({
    required double amount,
    required String paymentMethodId,
    List<Map<String, dynamic>> items = const [],
    String currency = 'usd',
    String? notes,
  }) async {
    try {
      debugPrint('PaymentService.checkout called with:');
      debugPrint('  - paymentMethodId: $paymentMethodId');
      debugPrint('  - amount: $amount');
      debugPrint('  - currency: $currency');
      debugPrint('  - items: ${items.length} items');
      debugPrint('  - notes: $notes');
      
      final response = await ApiService.post(
        '${ApiConfig.paymentsEndpoint}/checkout',
        {
          'paymentMethodId': paymentMethodId,
          'amount': amount,
          'currency': currency,
          'items': items,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        requiresAuth: true,
      );

      final receipt = response['receipt'];
      if (receipt is Map<String, dynamic>) {
        return receipt;
      }
      throw Exception('Invalid receipt response');
    } catch (e) {
      debugPrint('PaymentService.checkout error: $e');
      throw Exception('Failed to process payment: $e');
    }
  }
}

