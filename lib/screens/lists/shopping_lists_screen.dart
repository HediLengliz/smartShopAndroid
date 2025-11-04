import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.get(ApiConfig.shoppingListsEndpoint, requiresAuth: true);
      _lists = (data['lists'] as List?) ?? data as List? ?? [];
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Lists')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _promptNewList(context);
          if (name == null || name.trim().isEmpty) return;
          try {
            await ApiService.post(ApiConfig.shoppingListsEndpoint, {'name': name}, requiresAuth: true);
            _load();
          } catch (_) {}
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _lists.length,
                    itemBuilder: (_, i) {
                      final l = _lists[i];
                      return ListTile(
                        leading: const Icon(Icons.list_alt_outlined),
                        title: Text(l['name']),
                        subtitle: Text('${l['item_count']} items, ${l['purchased_count']} purchased'),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(),
                  ),
                ),
    );
  }

  Future<String?> _promptNewList(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New List'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'List name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );
  }
}


