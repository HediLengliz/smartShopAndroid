import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/shopping_list.dart';
import '../../services/shopping_list_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({super.key});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  List<ShoppingList> _shoppingLists = [];
  bool _isLoading = true;
  ShoppingList? _selectedList;

  @override
  void initState() {
    super.initState();
    _loadShoppingLists();
  }

  Future<void> _loadShoppingLists() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final lists = await ShoppingListService.getShoppingLists();
      setState(() {
        _shoppingLists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load shopping lists: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateQRData(ShoppingList list) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? '';
    // Generate a shareable link or data for the shopping list
    return 'smartshop://shopping-list/${list.id}?userId=$userId&name=${Uri.encodeComponent(list.name)}';
  }

  Future<void> _shareQRCode(ShoppingList list) async {
    try {
      final qrData = _generateQRData(list);
      await Share.share(
        'Check out my shopping list: ${list.name}\n\nScan the QR code or use this link:\n$qrData',
        subject: 'Shopping List: ${list.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code for Shopping Lists'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shoppingLists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No shopping lists found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a shopping list to generate a QR code',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // List selector
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<ShoppingList>(
                        decoration: InputDecoration(
                          labelText: 'Select Shopping List',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.list),
                        ),
                        value: _selectedList ?? (_shoppingLists.isNotEmpty ? _shoppingLists.first : null),
                        items: _shoppingLists.map((list) {
                          return DropdownMenuItem<ShoppingList>(
                            value: list,
                            child: Text(list.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedList = value;
                          });
                        },
                      ),
                    ),
                    // QR Code display
                    if (_selectedList != null)
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: _generateQRData(_selectedList!),
                                    version: QrVersions.auto,
                                    size: 250,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _selectedList!.name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_selectedList!.itemCount} items',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _shareQRCode(_selectedList!),
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share QR Code'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

