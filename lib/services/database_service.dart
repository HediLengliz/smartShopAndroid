import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'smart_shop.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Products table for offline caching
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        image_url TEXT,
        category TEXT,
        stock_quantity INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT,
        synced_at TEXT
      )
    ''');

    // Cart items table
    await db.execute('''
      CREATE TABLE cart_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        added_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // Shopping lists table (local copy)
    await db.execute('''
      CREATE TABLE shopping_lists (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        name TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT,
        synced_at TEXT
      )
    ''');

    // Shopping list items table
    await db.execute('''
      CREATE TABLE shopping_list_items (
        id INTEGER PRIMARY KEY,
        list_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER DEFAULT 1,
        is_purchased INTEGER DEFAULT 0,
        position INTEGER DEFAULT 0,
        created_at TEXT,
        FOREIGN KEY (list_id) REFERENCES shopping_lists(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // Orders table (local copy)
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        address_id INTEGER,
        total_amount REAL NOT NULL,
        status TEXT DEFAULT 'pending',
        payment_status TEXT DEFAULT 'pending',
        payment_intent_id TEXT,
        stripe_charge_id TEXT,
        tracking_number TEXT,
        created_at TEXT,
        updated_at TEXT,
        synced_at TEXT
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON cart_items(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shopping_lists_user_id ON shopping_lists(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shopping_list_items_list_id ON shopping_list_items(list_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database upgrades here if needed
  }

  // Products operations
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert(
      'products',
      product,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getProducts({String? category}) async {
    final db = await database;
    if (category != null) {
      return await db.query(
        'products',
        where: 'category = ? AND is_active = 1',
        whereArgs: [category],
        orderBy: 'name',
      );
    }
    return await db.query(
      'products',
      where: 'is_active = 1',
      orderBy: 'name',
    );
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Cart operations
  Future<int> addToCart(int productId, int quantity) async {
    final db = await database;

    // Check if item already exists in cart
    final existing = await db.query(
      'cart_items',
      where: 'product_id = ?',
      whereArgs: [productId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Update quantity
      final int currentQuantity = existing.first['quantity'] as int;
      final int newQuantity = currentQuantity + quantity;
      return await db.update(
        'cart_items',
        {'quantity': newQuantity},
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    } else {
      // Insert new item
      return await db.insert(
        'cart_items',
        {
          'product_id': productId,
          'quantity': quantity,
          'added_at': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ci.*, p.name, p.price, p.image_url, p.stock_quantity
      FROM cart_items ci
      JOIN products p ON ci.product_id = p.id
      ORDER BY ci.added_at DESC
    ''');
  }

  Future<int> updateCartItem(int productId, int quantity) async {
    final db = await database;
    return await db.update(
      'cart_items',
      {'quantity': quantity},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> removeFromCart(int productId) async {
    final db = await database;
    return await db.delete(
      'cart_items',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> clearCart() async {
    final db = await database;
    return await db.delete('cart_items');
  }

  // Shopping lists operations
  Future<int> insertShoppingList(Map<String, dynamic> list) async {
    final db = await database;
    return await db.insert(
      'shopping_lists',
      list,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getShoppingLists(int? userId) async {
    final db = await database;
    if (userId != null) {
      return await db.query(
        'shopping_lists',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'updated_at DESC',
      );
    }
    return await db.query('shopping_lists', orderBy: 'updated_at DESC');
  }

  Future<int> insertShoppingListItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert(
      'shopping_list_items',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getShoppingListItems(int listId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sli.*, p.name as product_name, p.price, p.image_url
      FROM shopping_list_items sli
      JOIN products p ON sli.product_id = p.id
      WHERE sli.list_id = ?
      ORDER BY sli.position, sli.created_at
    ''', [listId]);
  }

  // Orders operations
  Future<int> insertOrder(Map<String, dynamic> order) async {
    final db = await database;
    return await db.insert(
      'orders',
      order,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getOrders(int? userId) async {
    final db = await database;
    if (userId != null) {
      return await db.query(
        'orders',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
    }
    return await db.query('orders', orderBy: 'created_at DESC');
  }

  // Utility methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('cart_items');
    await db.delete('shopping_list_items');
    await db.delete('shopping_lists');
    await db.delete('orders');
    await db.delete('products');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}