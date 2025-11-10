import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shopping_list.dart';
import '../models/product.dart';
import '../services/shopping_list_service.dart';

class ShoppingListProvider with ChangeNotifier {
  List<ShoppingList> _lists = [];
  bool _isLoading = false;
  ListSortType _currentSortType = ListSortType.dateNewest;

  List<ShoppingList> get lists => _getSortedLists();
  bool get isLoading => _isLoading;
  ListSortType get currentSortType => _currentSortType;

  // Initialize the provider and load saved sort preference
  ShoppingListProvider() {
    _loadSortPreference();
  }

  Future<void> _loadSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSortIndex = prefs.getInt('shopping_list_sort_type') ?? ListSortType.dateNewest.index;
      _currentSortType = ListSortType.values[savedSortIndex];
      notifyListeners();
    } catch (e) {
      print('Error loading sort preference: $e');
    }
  }

  Future<void> _saveSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('shopping_list_sort_type', _currentSortType.index);
    } catch (e) {
      print('Error saving sort preference: $e');
    }
  }

  // Get sorted lists based on current sort type
  List<ShoppingList> _getSortedLists() {
    List<ShoppingList> sortedLists = List.from(_lists);

    switch (_currentSortType) {
      case ListSortType.nameAsc:
        sortedLists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ListSortType.nameDesc:
        sortedLists.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case ListSortType.dateNewest:
        sortedLists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case ListSortType.dateOldest:
        sortedLists.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case ListSortType.progressHigh:
        sortedLists.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case ListSortType.progressLow:
        sortedLists.sort((a, b) => a.progress.compareTo(b.progress));
        break;
      case ListSortType.itemCountHigh:
        sortedLists.sort((a, b) => b.itemCount.compareTo(a.itemCount));
        break;
      case ListSortType.itemCountLow:
        sortedLists.sort((a, b) => a.itemCount.compareTo(b.itemCount));
        break;
      case ListSortType.lastAdded:
        sortedLists.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return sortedLists;
  }

  // Change sort type and save preference
  void changeSortType(ListSortType newSortType) {
    _currentSortType = newSortType;
    _saveSortPreference();
    notifyListeners();
  }

  // Get all available sort types
  List<ListSortType> getAvailableSortTypes() {
    return ListSortType.values;
  }

  // Get statistics for all lists combined
  ListStatistics getOverallStatistics() {
    double totalCost = 0.0;
    int totalItems = 0;
    int completedItems = 0;
    Set<String> allCategories = {};

    for (final list in _lists) {
      totalItems += list.itemCount;
      completedItems += list.purchasedCount;
      // Note: We don't have cost data at list level, so we estimate
      totalCost += list.itemCount * 10.0; // Placeholder average price
    }

    return ListStatistics(
      estimatedTotalCost: double.parse(totalCost.toStringAsFixed(2)),
      uniqueCategories: allCategories.length,
      costPerItem: totalItems > 0 ? double.parse((totalCost / totalItems).toStringAsFixed(2)) : 0.0,
      completedItems: completedItems,
      totalItems: totalItems,
      completionRate: totalItems > 0 ? double.parse((completedItems / totalItems).toStringAsFixed(2)) : 0.0,
      categoryBreakdown: {},
      averageItemPrice: totalItems > 0 ? double.parse((totalCost / totalItems).toStringAsFixed(2)) : 0.0,
      remainingCost: double.parse((totalCost * (1 - (completedItems / totalItems))).toStringAsFixed(2)),
      purchasedCost: double.parse((totalCost * (completedItems / totalItems)).toStringAsFixed(2)),
    );
  }

  Future<void> fetchLists() async {
    _isLoading = true;
    notifyListeners();

    try {
      final lists = await ShoppingListService.getShoppingLists();
      _lists = lists;
    } catch (e) {
      print('Error fetching lists: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createList(String name) async {
    try {
      final newList = await ShoppingListService.createShoppingList(name);
      _lists.insert(0, newList);
      notifyListeners();
    } catch (e) {
      print('Error creating list: $e');
      rethrow;
    }
  }

  Future<void> createListWithItems(String name, List<Product> products) async {
    try {
      print('🛒 Creating list "$name" with ${products.length} products');

      // Create the list first
      final newList = await ShoppingListService.createShoppingList(name);
      print('✅ List created with ID: ${newList.id}');

      // Add each product to the list
      for (final product in products) {
        print('➕ Adding product: ${product.name} (ID: ${product.id})');
        try {
          await ShoppingListService.addItemToList(
            newList.id,
            product.id,
          );
          print('✅ Product ${product.name} added successfully');
        } catch (e) {
          print('❌ Failed to add product ${product.name}: $e');
          // Continue with other products even if one fails
        }
      }

      await fetchLists(); // Refresh lists to get updated item counts
      print('✅ List creation completed successfully');

    } catch (e) {
      print('❌ Error creating list with items: $e');
      rethrow;
    }
  }

  Future<void> updateList(int id, String name) async {
    try {
      final updatedList = await ShoppingListService.updateShoppingList(id, name);
      final index = _lists.indexWhere((list) => list.id == id);
      if (index != -1) {
        _lists[index] = updatedList;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating list: $e');
      rethrow;
    }
  }

  Future<void> deleteList(int id) async {
    try {
      await ShoppingListService.deleteShoppingList(id);
      _lists.removeWhere((list) => list.id == id);
      notifyListeners();
    } catch (e) {
      print('Error deleting list: $e');
      rethrow;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      return await ShoppingListService.searchProducts(query);
    } catch (e) {
      print('Error searching products: $e');
      rethrow;
    }
  }

  // Helper method to get a specific list by ID
  ShoppingList? getListById(int id) {
    try {
      return _lists.firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear all lists (useful for logout)
  void clearLists() {
    _lists.clear();
    notifyListeners();
  }
}