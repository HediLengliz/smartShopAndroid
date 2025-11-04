import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _methods = [];

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
      final data = await ApiService.get('${ApiConfig.paymentsEndpoint}/methods', requiresAuth: true);
      _methods = (data['paymentMethods'] as List?) ?? [];
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _loading = false);
  }

  Future<void> _delete(int id) async {
    try {
      await ApiService.delete('${ApiConfig.paymentsEndpoint}/methods/$id', requiresAuth: true);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _methods.length,
                    itemBuilder: (_, i) {
                      final m = _methods[i];
                      return ListTile(
                        leading: const Icon(Icons.credit_card),
                        title: Text('${m['card_brand']?.toString().toUpperCase()} •••• ${m['card_last4']}'),
                        subtitle: Text('Exp ${m['card_exp_month']}/${m['card_exp_year']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(m['id'] as int),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(),
                  ),
                ),
    );
  }
}


