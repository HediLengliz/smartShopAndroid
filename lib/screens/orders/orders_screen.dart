import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import 'order_details_dialog.dart';
import 'favorite_orders_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String _sortBy = 'created_at';
  String _sortOrder = 'DESC';
  String _searchQuery = '';
  String? _statusFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final orders = await OrderService.getOrders(
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _statusFilter,
      );

      setState(() {
        _orders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadOrders();
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date (Newest First)'),
              leading: Radio<String>(
                value: 'created_at_DESC',
                groupValue: '${_sortBy}_$_sortOrder',
                onChanged: (value) {
                  setState(() {
                    _sortBy = 'created_at';
                    _sortOrder = 'DESC';
                  });
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Date (Oldest First)'),
              leading: Radio<String>(
                value: 'created_at_ASC',
                groupValue: '${_sortBy}_$_sortOrder',
                onChanged: (value) {
                  setState(() {
                    _sortBy = 'created_at';
                    _sortOrder = 'ASC';
                  });
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Amount (High to Low)'),
              leading: Radio<String>(
                value: 'total_amount_DESC',
                groupValue: '${_sortBy}_$_sortOrder',
                onChanged: (value) {
                  setState(() {
                    _sortBy = 'total_amount';
                    _sortOrder = 'DESC';
                  });
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Amount (Low to High)'),
              leading: Radio<String>(
                value: 'total_amount_ASC',
                groupValue: '${_sortBy}_$_sortOrder',
                onChanged: (value) {
                  setState(() {
                    _sortBy = 'total_amount';
                    _sortOrder = 'ASC';
                  });
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Order ID'),
              leading: Radio<String>(
                value: 'id_DESC',
                groupValue: '${_sortBy}_$_sortOrder',
                onChanged: (value) {
                  setState(() {
                    _sortBy = 'id';
                    _sortOrder = 'DESC';
                  });
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter By Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('All Orders'),
              leading: Radio<String?>(
                value: null,
                groupValue: _statusFilter,
                onChanged: (value) {
                  setState(() => _statusFilter = value);
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Pending'),
              leading: Radio<String?>(
                value: 'pending',
                groupValue: _statusFilter,
                onChanged: (value) {
                  setState(() => _statusFilter = value);
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Completed'),
              leading: Radio<String?>(
                value: 'completed',
                groupValue: _statusFilter,
                onChanged: (value) {
                  setState(() => _statusFilter = value);
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Shipped'),
              leading: Radio<String?>(
                value: 'shipped',
                groupValue: _statusFilter,
                onChanged: (value) {
                  setState(() => _statusFilter = value);
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ListTile(
              title: const Text('Cancelled'),
              leading: Radio<String?>(
                value: 'cancelled',
                groupValue: _statusFilter,
                onChanged: (value) {
                  setState(() => _statusFilter = value);
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Order order) async {
    try {
      await OrderService.toggleFavorite(order.id, !order.isFavorite);
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              order.isFavorite ? 'Removed from favorites' : 'Added to favorites',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteOrder(Order order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Are you sure you want to delete order #${order.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await OrderService.deleteOrder(order.id);
        _loadOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showOrderDetails(Order order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => OrderDetailsDialog(orderId: order.id),
    );

    // Reload orders if any changes were made
    if (result == true) {
      _loadOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteOrdersScreen(),
                ),
              ).then((_) => _loadOrders());
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by order ID or tracking number',
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              onChanged: _onSearch,
            ),
          ),

          // Orders list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No orders found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        color: Colors.orange,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return _buildOrderCard(order);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          order.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: order.isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(order),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteOrder(order);
                          } else if (value == 'details') {
                            _showOrderDetails(order);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 20),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.statusDisplay,
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPaymentStatusColor(order.paymentStatus)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.paymentStatusDisplay,
                      style: TextStyle(
                        color: _getPaymentStatusColor(order.paymentStatus),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(order.createdAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Items: ${order.itemCount}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (order.trackingNumber != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tracking: ${order.trackingNumber}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    currencyFormatter.format(order.totalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'processing':
      case 'shipped':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
      case 'succeeded':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

