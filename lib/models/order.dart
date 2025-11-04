class Order {
  final int id;
  final int userId;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String? trackingNumber;
  final DateTime? createdAt;
  final List<OrderItem>? items;

  Order({
    required this.id,
    required this.userId,
    required this.totalAmount,
    this.status = 'pending',
    this.paymentStatus = 'pending',
    this.trackingNumber,
    this.createdAt,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      userId: json['user_id'] ?? json['userId'],
      totalAmount: (json['total_amount'] ?? json['totalAmount'] is String)
          ? double.parse(json['total_amount'] ?? json['totalAmount'])
          : (json['total_amount'] ?? json['totalAmount']).toDouble(),
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? json['paymentStatus'] ?? 'pending',
      trackingNumber: json['tracking_number'] ?? json['trackingNumber'],
      createdAt: json['created_at'] != null || json['createdAt'] != null
          ? DateTime.parse(json['created_at'] ?? json['createdAt'])
          : null,
      items: json['items'] != null
          ? (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList()
          : null,
    );
  }
}

class OrderItem {
  final int id;
  final int orderId;
  final int productId;
  final String? productName;
  final int quantity;
  final double priceAtPurchase;
  final String? imageUrl;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.priceAtPurchase,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int,
      orderId: json['order_id'] ?? json['orderId'],
      productId: json['product_id'] ?? json['productId'],
      productName: json['product_name'] ?? json['productName'],
      quantity: json['quantity'] as int,
      priceAtPurchase: (json['price_at_purchase'] ?? json['priceAtPurchase'] is String)
          ? double.parse(json['price_at_purchase'] ?? json['priceAtPurchase'])
          : (json['price_at_purchase'] ?? json['priceAtPurchase']).toDouble(),
      imageUrl: json['image_url'] ?? json['imageUrl'],
    );
  }

  double get total => priceAtPurchase * quantity;
}
