import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../home/widgets/home_template.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return HomeTemplate(
      currentIndex: 2, // ✅ Active icon Cart in bottom bar
      appBar: AppBar(
        title: const Text("My Cart"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),

      body: cart.items.isEmpty
          ? const Center(
        child: Text("Your cart is empty"),
      )
          : Column(
        children: [
          Expanded(
            child: ListView(
              children: cart.items.entries.map((entry) {
                final product = entry.key;
                final qty = entry.value;

                return ListTile(
                  leading: product.imageUrl != null
                      ? Image.network(product.imageUrl!, width: 50)
                      : const Icon(Icons.shopping_bag),

                  title: Text(product.name),
                  subtitle: Text("\$${(product.price * qty).toStringAsFixed(2)}"),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => cart.removeProduct(product),
                      ),
                      Text("$qty"), // ✅ Just quantity (no equation)
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => cart.addProduct(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => cart.deleteProduct(product),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // ✅ Total section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total:",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "\$${cart.totalPrice.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text("Checkout"),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
