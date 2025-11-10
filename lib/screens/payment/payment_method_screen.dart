import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import '../../models/payment_method.dart' as app_models;
import '../../services/payment_service.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import 'payment_receipt_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, dynamic>> cartItems;
  final String currency;
  final String? orderNotes;
  final void Function(Map<String, dynamic> receipt)? onCheckoutSuccess;

  const PaymentMethodScreen({
    super.key,
    required this.totalAmount,
    required this.cartItems,
    this.currency = 'usd',
    this.orderNotes,
    this.onCheckoutSuccess,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardHolderNameController = TextEditingController();
  final _cardFieldController = stripe.CardEditController();

  bool _rememberPaymentMethod = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _stripeInitialized = false;
  List<app_models.PaymentMethod> _savedPaymentMethods = [];
  app_models.PaymentMethod? _selectedPaymentMethod;
  String? _publishableKey;
  String? _setupIntentClientSecret;

  @override
  void initState() {
    super.initState();
    _initializeStripe();
    _loadSavedPaymentMethods();
  }

  @override
  void dispose() {
    _cardHolderNameController.dispose();
    _cardFieldController.dispose();
    super.dispose();
  }

  Future<void> _initializeStripe() async {
    try {
      debugPrint('🔧 Initializing Stripe...');
      
      // Get setup intent and publishable key from backend
      final setupData = await PaymentService.getSetupIntent();

      debugPrint('✅ Setup data received');
      debugPrint('  - Publishable Key: ${setupData['publishableKey']?.substring(0, 20)}...');
      debugPrint('  - Client Secret: ${setupData['clientSecret']?.substring(0, 20)}...');

      setState(() {
        _publishableKey = setupData['publishableKey'];
        _setupIntentClientSecret = setupData['clientSecret'];
        _isInitializing = false;
      });

      // Initialize Stripe with publishable key
      if (_publishableKey != null && _publishableKey!.isNotEmpty) {
        try {
          stripe.Stripe.publishableKey = _publishableKey!;
          if (!kIsWeb) {
            // iOS/Android specific settings
            stripe.Stripe.merchantIdentifier = 'merchant.com.smartshop.app';
            await stripe.Stripe.instance.applySettings();
          }

          // Give Stripe a moment to fully initialize
          await Future.delayed(const Duration(milliseconds: 200));

          setState(() {
            _stripeInitialized = true;
          });

          debugPrint('✅ Stripe fully initialized and ready');
        } catch (e) {
          debugPrint('❌ Error setting Stripe key: $e');
          throw Exception('Failed to initialize Stripe: $e');
        }
      } else {
        throw Exception('Publishable key is empty');
      }
    } catch (e) {
      debugPrint('❌ Error initializing Stripe: $e');
      setState(() {
        _isInitializing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize payment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadSavedPaymentMethods() async {
    try {
      final methods = await PaymentService.getPaymentMethods();
      setState(() {
        _savedPaymentMethods = methods;
        if (methods.isNotEmpty) {
          _selectedPaymentMethod = methods.firstWhere(
                (m) => m.isDefault,
            orElse: () => methods.first,
          );
        } else {
          _selectedPaymentMethod = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    }
  }

  Future<String?> _createPaymentMethod() async {
    if (_setupIntentClientSecret == null) {
      throw Exception('Setup intent not initialized');
    }

    try {
      // Validate card field
      final cardDetails = _cardFieldController.details;
      if (cardDetails == null || !cardDetails.complete) {
        throw Exception('Please complete all card details');
      }

      // Create payment method from card field
      // Note: CardField handles card collection securely
      final billingName = _cardHolderNameController.text.trim().isNotEmpty
          ? _cardHolderNameController.text.trim()
          : null;

      // Create payment method using Stripe with card field data
      final stripePaymentMethod = await stripe.Stripe.instance.createPaymentMethod(
        params: stripe.PaymentMethodParams.card(
          paymentMethodData: stripe.PaymentMethodData(
            billingDetails: billingName != null
                ? stripe.BillingDetails(name: billingName)
                : null,
          ),
        ),
      );

      final paymentMethodId = stripePaymentMethod.id;
      if (paymentMethodId == null || paymentMethodId.isEmpty) {
        throw Exception('Failed to create payment method');
      }

      // Confirm setup intent with the payment method
      // The setup intent will be confirmed when we attach the payment method
      // We'll let the backend handle the setup intent confirmation
      // For now, we just save the payment method which will attach it to the customer
      
      // Save payment method to backend (this will attach to customer and confirm setup intent)
      final savedPaymentMethod = await PaymentService.savePaymentMethod(
        paymentMethodId: paymentMethodId,
        isDefault: _rememberPaymentMethod && _savedPaymentMethods.isEmpty,
      );

      // Send notification if payment method was saved
      if (_rememberPaymentMethod && savedPaymentMethod.cardLast4 != null) {
        try {
          final notificationProvider = context.read<NotificationProvider>();
          await NotificationService.notifyPaymentMethodAdded(savedPaymentMethod.cardLast4!);
          await notificationProvider.refresh();
        } catch (e) {
          debugPrint('Error sending payment method notification: $e');
        }
      }

      return savedPaymentMethod.stripePaymentMethodId;
    } catch (e) {
      debugPrint('Error creating payment method: $e');
      rethrow;
    }
  }

  Future<void> _handlePayment() async {
    if (_isLoading || _isInitializing) return;

    setState(() => _isLoading = true);

    try {
      String? paymentMethodId;

      if (_selectedPaymentMethod != null) {
        // Use saved payment method
        paymentMethodId = _selectedPaymentMethod!.stripePaymentMethodId;
      } else {
        // Validate form
        if (!_formKey.currentState!.validate()) {
          setState(() => _isLoading = false);
          return;
        }

        // Create new payment method using Stripe
        paymentMethodId = await _createPaymentMethod();

        // Reload saved payment methods if we saved a new one
        if (_rememberPaymentMethod) {
          await _loadSavedPaymentMethods();
        }
      }

      if (paymentMethodId == null) {
        throw Exception('Unable to determine payment method');
      }

      if (widget.cartItems.isEmpty) {
        throw Exception('Cart is empty. Please add items before checking out.');
      }

      final receipt = await PaymentService.checkout(
        amount: widget.totalAmount,
        paymentMethodId: paymentMethodId,
        currency: widget.currency,
        items: widget.cartItems,
        notes: widget.orderNotes,
      );

      widget.onCheckoutSuccess?.call(receipt);

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PaymentReceiptScreen(receipt: receipt),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Payment Method'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isInitializing || !_stripeInitialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 16),
                  Text('Initializing payment system...'),
                ],
              ),
            )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Saved Payment Methods Section
            if (_savedPaymentMethods.isNotEmpty) ...[
              const Text(
                'Saved Payment Methods',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ..._savedPaymentMethods.map((method) => _buildSavedPaymentMethodCard(method)),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Add New Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Payment Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stripe Card Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Card Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _stripeInitialized
                          ? stripe.CardField(
                              controller: _cardFieldController,
                              enablePostalCode: false,
                              autofocus: false,
                              decoration: InputDecoration(
                                labelText: 'Card number',
                                hintText: '1234 5678 9012 3456',
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.orange,
                                    width: 1.5,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                letterSpacing: 0.4,
                              ),
                              cursorColor: Colors.orange,
                            )
                          : const SizedBox(
                              height: 56,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the card number, expiry (MM/YY), and CVC exactly as shown on the card.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Card Holder Name
                  TextFormField(
                    controller: _cardHolderNameController,
                    decoration: InputDecoration(
                      labelText: 'Card Holder Name',
                      hintText: 'John Doe',
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter card holder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Remember Payment Method Checkbox
                  CheckboxListTile(
                    value: _rememberPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _rememberPaymentMethod = value ?? false;
                      });
                    },
                    title: const Text('Remember this payment method'),
                    activeColor: Colors.orange,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Total Amount Display (if provided)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    '\$${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pay Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                _selectedPaymentMethod != null
                    ? 'Pay with ${_selectedPaymentMethod!.displayName}'
                    : 'Continue to Payment',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPaymentMethodCard(app_models.PaymentMethod method) {
    final isSelected = _selectedPaymentMethod?.id == method.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.orange : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
            blurRadius: isSelected ? 8 : 2,
            offset: Offset(0, isSelected ? 4 : 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            // Toggle selection - if already selected, deselect it
            if (_selectedPaymentMethod?.id == method.id) {
              _selectedPaymentMethod = null;
            } else {
              _selectedPaymentMethod = method;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.credit_card,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expires ${method.expiryDate}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (method.isDefault)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.orange,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
