import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';

class PaymentReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;

  const PaymentReceiptScreen({super.key, required this.receipt});

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  bool _notificationSent = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendNotifications();
    });
  }

  Future<void> _sendNotifications() async {
    if (_notificationSent) return;
    if (!mounted) return;
    
    try {
      final notificationProvider = context.read<NotificationProvider>();
      final order = widget.receipt['order'] ?? {};
      final payment = widget.receipt['payment'] ?? {};
      
      final orderId = order['id'] as int?;
      final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 
                         (payment['amount'] as num?)?.toDouble() ?? 0.0;
      final paymentIntentId = payment['paymentIntentId'] as String?;
      
      // Send payment success notification
      if (paymentIntentId != null) {
        await NotificationService.notifyPaymentSuccess(
          paymentIntentId,
          totalAmount,
        );
      }
      
      // Send order created notification
      if (orderId != null) {
        await NotificationService.notifyOrderCreated(orderId, totalAmount);
      }
      
      // Refresh notifications
      await notificationProvider.refresh();
      
      _notificationSent = true;
    } catch (e) {
      debugPrint('Error sending notifications: $e');
    }
  }

  Map<String, dynamic> get order => widget.receipt['order'] ?? {};
  Map<String, dynamic> get customer => widget.receipt['customer'] ?? {};
  Map<String, dynamic> get payment => widget.receipt['payment'] ?? {};
  List<dynamic> get items => List<dynamic>.from(widget.receipt['items'] ?? []);

  String _formatCurrency(double value, String currency) {
    final formatter = NumberFormat.simpleCurrency(name: currency.toUpperCase());
    return formatter.format(value);
  }

  Future<void> _exportPdf(BuildContext context) async {
    final currency = (order['currency'] ?? payment['currency'] ?? 'usd').toString();
    final pdf = pw.Document();
    final date = DateTime.tryParse(order['createdAt'] ?? '') ?? DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('SmartShop Receipt', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Order ID: #${order['id'] ?? 'N/A'}'),
          pw.Text('Date: ${DateFormat.yMMMMd().add_jm().format(date)}'),
          pw.Text('Customer: ${(customer['firstName'] ?? '')} ${(customer['lastName'] ?? '')}'),
          pw.Text('Email: ${customer['email'] ?? ''}'),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Item', 'Qty', 'Unit Price', 'Total'],
            data: items.map((item) {
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final price = (item['price'] as num?)?.toDouble() ?? 0;
              final total = price * qty;
              return [
                item['name'] ?? 'Item',
                qty.toString(),
                _formatCurrency(price, currency),
                _formatCurrency(total, currency),
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Total Paid: ${_formatCurrency((order['totalAmount'] as num?)?.toDouble() ?? (payment['amount'] as num?)?.toDouble() ?? 0, currency)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Payment Method: ${(payment['method']?['brand'] ?? '').toString().toUpperCase()} •••• ${payment['method']?['last4'] ?? '****'}'),
          pw.Text('Payment Status: ${payment['status'] ?? 'unknown'}'),
          if (order['notes'] != null && (order['notes'] as String).isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text('Notes: ${order['notes']}'),
            ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final orderId = order['id'] ?? 'receipt';
    await Printing.sharePdf(bytes: bytes, filename: 'smartshop_receipt_$orderId.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final currency = (order['currency'] ?? payment['currency'] ?? 'usd').toString();
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? (payment['amount'] as num?)?.toDouble() ?? 0;
    final orderDate = DateTime.tryParse(order['createdAt'] ?? '') ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _infoRow('Order ID', '#${order['id'] ?? 'N/A'}'),
                    _infoRow('Date', DateFormat.yMMMMd().add_jm().format(orderDate)),
                    _infoRow('Status', (order['status'] ?? 'completed').toString()),
                    if (order['notes'] != null && (order['notes'] as String).isNotEmpty)
                      _infoRow('Notes', order['notes']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _infoRow('Name', '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'),
                    _infoRow('Email', customer['email'] ?? ''),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...items.map((item) {
                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                      final price = (item['price'] as num?)?.toDouble() ?? 0;
                      final lineTotal = qty * price;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name'] ?? 'Item'),
                        subtitle: Text('Qty: $qty • Unit: ${_formatCurrency(price, currency)}'),
                        trailing: Text(
                          _formatCurrency(lineTotal, currency),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: ${_formatCurrency(totalAmount, currency)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _infoRow('Status', payment['status'] ?? 'succeeded'),
                    _infoRow('Amount', _formatCurrency(totalAmount, currency)),
                    _infoRow(
                      'Balance Due',
                      _formatCurrency(
                        (order['balanceDue'] as num?)?.toDouble() ?? 0,
                        currency,
                      ),
                    ),
                    _infoRow(
                      'Method',
                      '${(payment['method']?['brand'] ?? '').toString().toUpperCase()} •••• ${payment['method']?['last4'] ?? '****'}',
                    ),
                    if (payment['receiptUrl'] != null)
                      TextButton(
                        onPressed: () async {
                          final url = payment['receiptUrl'];
                          if (url is String && url.isNotEmpty) {
                            final uri = Uri.parse(url);
                            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Unable to open receipt link'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('View Stripe Receipt'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _exportPdf(context),
                    child: const Text('Download / Print Receipt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to home screen and clear navigation stack
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home',
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value?.toString() ?? ''),
          ),
        ],
      ),
    );
  }
}

