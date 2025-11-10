import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';

class NotificationService {
  static const String _notificationsKey = 'app_notifications';
  static const int _maxNotifications = 100; // Keep last 100 notifications

  // Get all notifications
  static Future<List<AppNotification>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_notificationsKey);
      
      if (notificationsJson == null) {
        return [];
      }

      final List<dynamic> notificationsList = json.decode(notificationsJson);
      return notificationsList
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  // Get unread notifications count
  static Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  // Add a new notification
  static Future<void> addNotification(AppNotification notification) async {
    try {
      final notifications = await getNotifications();
      
      // Add new notification at the beginning
      notifications.insert(0, notification);
      
      // Keep only the last _maxNotifications
      if (notifications.length > _maxNotifications) {
        notifications.removeRange(_maxNotifications, notifications.length);
      }
      
      await _saveNotifications(notifications);
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications();
      final index = notifications.indexWhere((n) => n.id == notificationId);
      
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        await _saveNotifications(notifications);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      await _saveNotifications(updatedNotifications);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Delete a notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.id == notificationId);
      await _saveNotifications(notifications);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Delete all notifications
  static Future<void> deleteAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
    }
  }

  // Save notifications to storage
  static Future<void> _saveNotifications(List<AppNotification> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = json.encode(
        notifications.map((n) => n.toJson()).toList(),
      );
      await prefs.setString(_notificationsKey, notificationsJson);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  // Helper methods to create notifications for different events
  static Future<void> notifyProfileUpdated() async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Profile Updated',
      message: 'Your profile information has been updated successfully.',
      type: NotificationType.profile,
      createdAt: DateTime.now(),
    );
    await addNotification(notification);
  }

  static Future<void> notifyOrderCreated(int orderId, double totalAmount) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Order Placed',
      message: 'Your order #$orderId has been placed successfully. Total: \$${totalAmount.toStringAsFixed(2)}',
      type: NotificationType.order,
      createdAt: DateTime.now(),
      data: {'order_id': orderId},
    );
    await addNotification(notification);
  }

  static Future<void> notifyOrderStatusChanged(int orderId, String status) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Order Status Updated',
      message: 'Order #$orderId status has been updated to $status.',
      type: NotificationType.order,
      createdAt: DateTime.now(),
      data: {'order_id': orderId, 'status': status},
    );
    await addNotification(notification);
  }

  static Future<void> notifyPaymentSuccess(String paymentIntentId, double amount) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Payment Successful',
      message: 'Your payment of \$${amount.toStringAsFixed(2)} has been processed successfully.',
      type: NotificationType.payment,
      createdAt: DateTime.now(),
      data: {'payment_intent_id': paymentIntentId, 'amount': amount},
    );
    await addNotification(notification);
  }

  static Future<void> notifyPaymentMethodAdded(String cardLast4) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Payment Method Added',
      message: 'A new payment method ending in $cardLast4 has been added to your account.',
      type: NotificationType.payment,
      createdAt: DateTime.now(),
      data: {'card_last4': cardLast4},
    );
    await addNotification(notification);
  }

  static Future<void> notifyShoppingListUpdated(String listName) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Shopping List Updated',
      message: 'Your shopping list "$listName" has been updated.',
      type: NotificationType.shoppingList,
      createdAt: DateTime.now(),
      data: {'list_name': listName},
    );
    await addNotification(notification);
  }

  static Future<void> notifyShoppingListCreated(String listName, int itemCount) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Shopping List Created',
      message: 'Your shopping list "$listName" has been created with $itemCount item${itemCount != 1 ? 's' : ''}.',
      type: NotificationType.shoppingList,
      createdAt: DateTime.now(),
      data: {'list_name': listName, 'item_count': itemCount},
    );
    await addNotification(notification);
  }

  static Future<void> notifyShoppingListProcessed(String listName, int itemCount, double totalAmount) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Shopping List Processed',
      message: 'Items from "$listName" have been added to cart. Total: \$${totalAmount.toStringAsFixed(2)}',
      type: NotificationType.shoppingList,
      createdAt: DateTime.now(),
      data: {'list_name': listName, 'item_count': itemCount, 'total_amount': totalAmount},
    );
    await addNotification(notification);
  }

  static Future<void> notifyShoppingListCheckedOut(String listName, int itemCount, double totalAmount, int? orderId) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Shopping List Checked Out',
      message: 'Your shopping list "$listName" has been processed and order${orderId != null ? ' #$orderId' : ''} has been placed. Total: \$${totalAmount.toStringAsFixed(2)}',
      type: NotificationType.shoppingList,
      createdAt: DateTime.now(),
      data: {'list_name': listName, 'item_count': itemCount, 'total_amount': totalAmount, 'order_id': orderId},
    );
    await addNotification(notification);
  }
}

