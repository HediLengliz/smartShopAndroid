class ShoppingList {
  final int id;
  final int userId;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? itemCount;
  final int? purchasedCount;
  final List<ShoppingListItem>? items;

  ShoppingList({
    required this.id,
    required this.userId,
    required this.name,
    this.createdAt,
    this.updatedAt,
    this.itemCount,
    this.purchasedCount,
    this.items,
  });

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as int,
      userId: json['user_id'] ?? json['userId'],
      name: json['name'] as String,
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.parse(json['created_at'] ?? json['createdAt'])
          : null,
      updatedAt: json['updated_at'] != null || json['updatedAt'] != null
          ? DateTime.parse(json['updated_at'] ?? json['updatedAt'])
          : null,
      itemCount: json['item_count'] ?? json['itemCount'],
      purchasedCount: json['purchased_count'] ?? json['purchasedCount'],
      items: json['items'] != null
          ? (json['items'] as List).map((item) => ShoppingListItem.fromJson(item)).toList()
          : null,
    );
  }
}

class ShoppingListItem {
  final int id;
  final int listId;
  final int productId;
  final String? productName;
  final double? price;
  final String? imageUrl;
  final int quantity;
  final bool isPurchased;
  final int position;

  ShoppingListItem({
    required this.id,
    required this.listId,
    required this.productId,
    this.productName,
    this.price,
    this.imageUrl,
    this.quantity = 1,
    this.isPurchased = false,
    this.position = 0,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as int,
      listId: json['list_id'] ?? json['listId'],
      productId: json['product_id'] ?? json['productId'],
      productName: json['product_name'] ?? json['productName'],
      price: json['price'] != null
          ? (json['price'] is String ? double.parse(json['price']) : (json['price'] as num).toDouble())
          : null,
      imageUrl: json['image_url'] ?? json['imageUrl'],
      quantity: json['quantity'] ?? 1,
      isPurchased: json['is_purchased'] ?? json['isPurchased'] ?? false,
      position: json['position'] ?? 0,
    );
  }

  ShoppingListItem copyWith({
    int? quantity,
    bool? isPurchased,
    int? position,
  }) {
    return ShoppingListItem(
      id: id,
      listId: listId,
      productId: productId,
      productName: productName,
      price: price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
      isPurchased: isPurchased ?? this.isPurchased,
      position: position ?? this.position,
    );
  }
}
