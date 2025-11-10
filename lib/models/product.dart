class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? category;
  final int stockQuantity;
  final int isActive;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.category,
    this.stockQuantity = 0,
    this.isActive = 1,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] is String)
          ? double.parse(json['price'])
          : (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] ?? json['imageUrl'],
      category: json['category'] as String?,
      stockQuantity: json['stock_quantity'] ?? json['stockQuantity'] ?? 0,
      isActive: (json['is_active'] is int)
          ? json['is_active'] as int
          : (json['is_active'] == true ? 1 : 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'stockQuantity': stockQuantity,
      'isActive': isActive,
    };
  }

  bool get inStock => stockQuantity > 0;
}
