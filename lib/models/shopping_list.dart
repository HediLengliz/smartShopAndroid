import 'package:flutter/material.dart';
import '../models/shopping_list_item.dart';

// Add this enum at the top of the file
enum ListSortType {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  progressHigh,
  progressLow,
  itemCountHigh,
  itemCountLow,
  lastAdded
}

class ShoppingList {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;
  final int purchasedCount;

  ShoppingList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.itemCount = 0,
    this.purchasedCount = 0,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as int,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      itemCount: json['item_count'] as int? ?? 0,
      purchasedCount: json['purchased_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get progress {
    if (itemCount == 0) return 0.0;
    return purchasedCount / itemCount;
  }

  bool get isCompleted => progress == 1.0;

  // Helper method to get sort type display name
  static String getSortTypeName(ListSortType sortType) {
    switch (sortType) {
      case ListSortType.nameAsc:
        return 'Name (A-Z)';
      case ListSortType.nameDesc:
        return 'Name (Z-A)';
      case ListSortType.dateNewest:
        return 'Date (Newest)';
      case ListSortType.dateOldest:
        return 'Date (Oldest)';
      case ListSortType.progressHigh:
        return 'Progress (High)';
      case ListSortType.progressLow:
        return 'Progress (Low)';
      case ListSortType.itemCountHigh:
        return 'Items (Most)';
      case ListSortType.itemCountLow:
        return 'Items (Fewest)';
      case ListSortType.lastAdded:
        return 'Last Added';
    }
  }

  // Helper method to get sort type icon
  static IconData getSortTypeIcon(ListSortType sortType) {
    switch (sortType) {
      case ListSortType.nameAsc:
        return Icons.sort_by_alpha;
      case ListSortType.nameDesc:
        return Icons.sort_by_alpha;
      case ListSortType.dateNewest:
        return Icons.new_releases;
      case ListSortType.dateOldest:
        return Icons.history;
      case ListSortType.progressHigh:
        return Icons.trending_up;
      case ListSortType.progressLow:
        return Icons.trending_down;
      case ListSortType.itemCountHigh:
        return Icons.format_list_numbered;
      case ListSortType.itemCountLow:
        return Icons.format_list_bulleted;
      case ListSortType.lastAdded:
        return Icons.add_circle;
    }
  }
}

// New Statistics Model
class ListStatistics {
  final double estimatedTotalCost;
  final int uniqueCategories;
  final double costPerItem;
  final int completedItems;
  final int totalItems;
  final double completionRate;
  final Map<String, int> categoryBreakdown;
  final double averageItemPrice;
  final double remainingCost;
  final double purchasedCost;

  ListStatistics({
    required this.estimatedTotalCost,
    required this.uniqueCategories,
    required this.costPerItem,
    required this.completedItems,
    required this.totalItems,
    required this.completionRate,
    required this.categoryBreakdown,
    required this.averageItemPrice,
    required this.remainingCost,
    required this.purchasedCost,
  });

  // Helper method to calculate statistics from items
  static ListStatistics calculateFromItems(List<ShoppingListItem> items) {
    if (items.isEmpty) {
      return ListStatistics(
        estimatedTotalCost: 0.0,
        uniqueCategories: 0,
        costPerItem: 0.0,
        completedItems: 0,
        totalItems: 0,
        completionRate: 0.0,
        categoryBreakdown: {},
        averageItemPrice: 0.0,
        remainingCost: 0.0,
        purchasedCost: 0.0,
      );
    }

    // Calculate costs
    double totalCost = 0.0;
    double purchasedCost = 0.0;
    double remainingCost = 0.0;
    int completedItems = 0;
    int totalItems = items.length;

    Set<String> categories = {};
    Map<String, int> categoryCount = {};

    for (final item in items) {
      final itemCost = (item.price ?? 0) * item.quantity;
      totalCost += itemCost;

      if (item.isPurchased) {
        purchasedCost += itemCost;
        completedItems++;
      } else {
        remainingCost += itemCost;
      }

      // Handle categories - we'll need to get category from product data
      // For now, use a placeholder since your current ShoppingListItem doesn't have category
      final category = 'General'; // This will need to be updated when you add category to ShoppingListItem
      categories.add(category);
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }

    return ListStatistics(
      estimatedTotalCost: double.parse(totalCost.toStringAsFixed(2)),
      uniqueCategories: categories.length,
      costPerItem: totalItems > 0 ? double.parse((totalCost / totalItems).toStringAsFixed(2)) : 0.0,
      completedItems: completedItems,
      totalItems: totalItems,
      completionRate: totalItems > 0 ? double.parse((completedItems / totalItems).toStringAsFixed(2)) : 0.0,
      categoryBreakdown: categoryCount,
      averageItemPrice: totalItems > 0 ? double.parse((totalCost / totalItems).toStringAsFixed(2)) : 0.0,
      remainingCost: double.parse(remainingCost.toStringAsFixed(2)),
      purchasedCost: double.parse(purchasedCost.toStringAsFixed(2)),
    );
  }

  // Get top categories (sorted by count)
  List<MapEntry<String, int>> get topCategories {
    final entries = categoryBreakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  // Get category percentage
  double getCategoryPercentage(String category) {
    if (totalItems == 0) return 0.0;
    final count = categoryBreakdown[category] ?? 0;
    return double.parse((count / totalItems).toStringAsFixed(2));
  }
}
