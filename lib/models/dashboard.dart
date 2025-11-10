class TopProduct {
  final int? id;
  final String name;
  final String? imageUrl;
  final double price;
  final String? category;
  final int totalQuantity;
  final int orderCount;
  final double totalSpent;

  TopProduct({
    this.id,
    required this.name,
    this.imageUrl,
    required this.price,
    this.category,
    required this.totalQuantity,
    required this.orderCount,
    required this.totalSpent,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TopProduct(
      id: parseInt(json['id']),
      name: json['name'] as String? ?? 'Unknown Product',
      imageUrl: json['image_url'] as String?,
      price: parseDouble(json['price']),
      category: json['category'] as String?,
      totalQuantity: parseInt(json['total_quantity']),
      orderCount: parseInt(json['order_count']),
      totalSpent: parseDouble(json['total_spent']),
    );
  }
}

class SpendingTrend {
  final String month;
  final double total;
  final int orderCount;

  SpendingTrend({
    required this.month,
    required this.total,
    required this.orderCount,
  });

  factory SpendingTrend.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return SpendingTrend(
      month: json['month'] as String? ?? '',
      total: parseDouble(json['total']),
      orderCount: parseInt(json['order_count']),
    );
  }
}

class CategoryBreakdown {
  final String category;
  final int itemCount;
  final int totalQuantity;
  final double totalSpent;

  CategoryBreakdown({
    required this.category,
    required this.itemCount,
    required this.totalQuantity,
    required this.totalSpent,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return CategoryBreakdown(
      category: json['category'] as String? ?? 'Other',
      itemCount: parseInt(json['item_count']),
      totalQuantity: parseInt(json['total_quantity']),
      totalSpent: parseDouble(json['total_spent']),
    );
  }
}

class PurchaseTimeline {
  final String date;
  final int orderCount;
  final double dailyTotal;

  PurchaseTimeline({
    required this.date,
    required this.orderCount,
    required this.dailyTotal,
  });

  factory PurchaseTimeline.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return PurchaseTimeline(
      date: json['date'] as String? ?? '',
      orderCount: parseInt(json['order_count']),
      dailyTotal: parseDouble(json['daily_total']),
    );
  }
}

class OverallStats {
  final int totalOrders;
  final double totalSpent;
  final double avgOrderValue;
  final double highestOrder;
  final double lowestOrder;

  OverallStats({
    required this.totalOrders,
    required this.totalSpent,
    required this.avgOrderValue,
    required this.highestOrder,
    required this.lowestOrder,
  });

  factory OverallStats.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return OverallStats(
      totalOrders: parseInt(json['total_orders']),
      totalSpent: parseDouble(json['total_spent']),
      avgOrderValue: parseDouble(json['avg_order_value']),
      highestOrder: parseDouble(json['highest_order']),
      lowestOrder: parseDouble(json['lowest_order']),
    );
  }
}

class RecentOrder {
  final int id;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;

  RecentOrder({
    required this.id,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
  });

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    // Helper to parse numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return RecentOrder(
      id: parseInt(json['id']),
      totalAmount: parseDouble(json['total_amount']),
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class DashboardData {
  final List<TopProduct> topProducts;
  final List<RecentOrder> recentOrders;
  final List<SpendingTrend> spendingTrend;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<PurchaseTimeline> purchaseTimeline;
  final OverallStats overallStats;

  DashboardData({
    required this.topProducts,
    required this.recentOrders,
    required this.spendingTrend,
    required this.categoryBreakdown,
    required this.purchaseTimeline,
    required this.overallStats,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      topProducts: (json['topProducts'] as List<dynamic>?)
              ?.map((item) => TopProduct.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      recentOrders: (json['recentOrders'] as List<dynamic>?)
              ?.map((item) => RecentOrder.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      spendingTrend: (json['spendingTrend'] as List<dynamic>?)
              ?.map((item) => SpendingTrend.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      categoryBreakdown: (json['categoryBreakdown'] as List<dynamic>?)
              ?.map((item) => CategoryBreakdown.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      purchaseTimeline: (json['purchaseTimeline'] as List<dynamic>?)
              ?.map((item) => PurchaseTimeline.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      overallStats: OverallStats.fromJson(json['overallStats'] as Map<String, dynamic>? ?? {}),
    );
  }
}

