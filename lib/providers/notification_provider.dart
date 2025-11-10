import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  List<AppNotification> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();

  // Load notifications
  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await NotificationService.getNotifications();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add notification
  Future<void> addNotification(AppNotification notification) async {
    await NotificationService.addNotification(notification);
    await loadNotifications(); // Reload to get updated list
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    await NotificationService.markAsRead(notificationId);
    await loadNotifications();
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    await NotificationService.markAllAsRead();
    await loadNotifications();
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await NotificationService.deleteNotification(notificationId);
    await loadNotifications();
  }

  // Delete all notifications
  Future<void> deleteAllNotifications() async {
    await NotificationService.deleteAllNotifications();
    await loadNotifications();
  }

  // Refresh notifications
  Future<void> refresh() async {
    await loadNotifications();
  }
}

