class ShoppingListItem {
  final int id;
  final int listId;
  final int productId;
  final String productName;
  final double? price;
  final String? imageUrl;
  final String? productCategory; // ADD THIS FIELD
  final int quantity;
  final bool isPurchased;
  final int position;
  final DateTime createdAt;

  ShoppingListItem({
    required this.id,
    required this.listId,
    required this.productId,
    required this.productName,
    this.price,
    this.imageUrl,
    this.productCategory, // ADD THIS
    required this.quantity,
    required this.isPurchased,
    required this.position,
    required this.createdAt,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    print('📦 ShoppingListItem JSON received: $json');

    // Handle is_purchased field - it can be int (0/1) or bool
    bool parseIsPurchased(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return false;
    }

    // Get product name with better fallback
    String getProductName(Map<String, dynamic> json) {
      final name = json['product_name'] ?? json['productName'] ?? json['name'];
      if (name != null && name is String && name.isNotEmpty) {
        return name;
      }
      final productId = json['product_id'] ?? json['productId'];
      if (productId != null) {
        return 'Product $productId';
      }
      return 'Unknown Product';
    }

    // Get product category - ADD THIS METHOD
    String? getProductCategory(Map<String, dynamic> json) {
      return json['product_category'] ?? json['category'];
    }

    // Get price with better parsing
    double? parsePrice(dynamic priceValue) {
      if (priceValue == null) return null;
      if (priceValue is double) return priceValue;
      if (priceValue is int) return priceValue.toDouble();
      if (priceValue is String) {
        return double.tryParse(priceValue);
      }
      return null;
    }

    return ShoppingListItem(
      id: json['id'] as int? ?? 0,
      listId: json['list_id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? json['productId'] as int? ?? 0,
      productName: getProductName(json),
      price: parsePrice(json['price']),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      productCategory: getProductCategory(json), // ADD THIS
      quantity: json['quantity'] as int? ?? 1,
      isPurchased: parseIsPurchased(json['is_purchased'] ?? json['isPurchased']),
      position: json['position'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'list_id': listId,
      'product_id': productId,
      'quantity': quantity,
      'is_purchased': isPurchased ? 1 : 0,
      'position': position,
    };
  }

  ShoppingListItem copyWith({
    int? id,
    int? listId,
    int? productId,
    String? productName,
    double? price,
    String? imageUrl,
    String? productCategory, // ADD THIS
    int? quantity,
    bool? isPurchased,
    int? position,
    DateTime? createdAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      productCategory: productCategory ?? this.productCategory, // ADD THIS
      quantity: quantity ?? this.quantity,
      isPurchased: isPurchased ?? this.isPurchased,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}