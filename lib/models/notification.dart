import 'package:flutter/material.dart';

enum NotificationType {
  profile,
  order,
  payment,
  shoppingList,
  system,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data; // Additional data (order ID, payment ID, etc.)

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.system,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'data': data,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  String get typeDisplay {
    switch (type) {
      case NotificationType.profile:
        return 'Profile';
      case NotificationType.order:
        return 'Order';
      case NotificationType.payment:
        return 'Payment';
      case NotificationType.shoppingList:
        return 'Shopping List';
      case NotificationType.system:
        return 'System';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case NotificationType.profile:
        return Icons.person;
      case NotificationType.order:
        return Icons.shopping_bag;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.shoppingList:
        return Icons.shopping_cart;
      case NotificationType.system:
        return Icons.notifications;
    }
  }
}

