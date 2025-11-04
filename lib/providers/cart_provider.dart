import 'package:flutter/material.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final Map<Product, int> _items = {}; // Product : quantity

  Map<Product, int> get items => _items;

  void addProduct(Product product) {
    if (_items.containsKey(product)) {
      _items[product] = _items[product]! + 1;
    } else {
      _items[product] = 1;
    }
    notifyListeners();
  }

  void removeProduct(Product product) {
    if (_items.containsKey(product)) {
      if (_items[product]! > 1) {
        _items[product] = _items[product]! - 1;
      } else {
        _items.remove(product);
      }
      notifyListeners();
    }
  }

  void deleteProduct(Product product) {
    _items.remove(product);
    notifyListeners();
  }

  double get totalPrice {
    double total = 0;
    _items.forEach((product, qty) {
      total += product.price * qty;
    });
    return total;
  }

  int get totalItems =>
      _items.values.fold(0, (sum, qty) => sum + qty);

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
