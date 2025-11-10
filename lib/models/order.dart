import 'package:flutter/foundation.dart';

class OrderItem {
  final int id;
  final int? productId;
  final int quantity;
  final double priceAtPurchase;
  final String? productName;
  final String? productDescription;
  final String? productImage;
  final String? productCategory;

  OrderItem({
    required this.id,
    this.productId,
    required this.quantity,
    required this.priceAtPurchase,
    this.productName,
    this.productDescription,
    this.productImage,
    this.productCategory,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Helper functions to safely parse numeric values (handles both string and num)
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    int? parseIntNullable(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return OrderItem(
      id: parseInt(json['id']),
      productId: parseIntNullable(json['product_id']),
      quantity: parseInt(json['quantity']),
      priceAtPurchase: parseDouble(json['price_at_purchase']),
      productName: json['product_name'] as String?,
      productDescription: json['product_description'] as String?,
      productImage: json['product_image'] as String?,
      productCategory: json['product_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'price_at_purchase': priceAtPurchase,
      'product_name': productName,
      'product_description': productDescription,
      'product_image': productImage,
      'product_category': productCategory,
    };
  }

  double get totalPrice => priceAtPurchase * quantity;
}

class Order {
  final int id;
  final int userId;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String? paymentIntentId;
  final String? stripeChargeId;
  final String? trackingNumber;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;
  final int itemCount;

  Order({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.paymentIntentId,
    this.stripeChargeId,
    this.trackingNumber,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.itemCount = 0,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Helper functions to safely parse numeric values (handles both string and num)
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    List<OrderItem> orderItems = [];
    
    if (json['items'] != null) {
      if (json['items'] is List) {
        orderItems = (json['items'] as List)
            .map((item) {
              try {
                return OrderItem.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                debugPrint('Error parsing order item: $e, item: $item');
                return null;
              }
            })
            .whereType<OrderItem>()
            .toList();
      }
    }

    return Order(
      id: parseInt(json['id']),
      userId: parseInt(json['user_id']),
      totalAmount: parseDouble(json['total_amount']),
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paymentIntentId: json['payment_intent_id'] as String?,
      stripeChargeId: json['stripe_charge_id'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      items: orderItems,
      itemCount: parseInt(json['item_count']) != 0 ? parseInt(json['item_count']) : orderItems.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'total_amount': totalAmount,
      'status': status,
      'payment_status': paymentStatus,
      'payment_intent_id': paymentIntentId,
      'stripe_charge_id': stripeChargeId,
      'tracking_number': trackingNumber,
      'is_favorite': isFavorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'item_count': itemCount,
    };
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'shipped':
        return 'Shipped';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String get paymentStatusDisplay {
    switch (paymentStatus.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'paid':
        return 'Paid';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      case 'succeeded':
        return 'Succeeded';
      default:
        return paymentStatus;
    }
  }
}
