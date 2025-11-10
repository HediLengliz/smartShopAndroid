import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/providers/auth_provider.dart';
import '/providers/notification_provider.dart';
import '../../payment/saved_payment_methods_screen.dart';
import '../../orders/orders_screen.dart';
import '../../profile/profile_screen.dart';
import '../../shopping_lists/shopping_lists_screen.dart';
import '../../settings/settings_screen.dart';
import '../../help_support/help_support_screen.dart';

class HomeTemplate extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final int currentIndex;

  const HomeTemplate({
    super.key,
    this.appBar,
    required this.body,
    required this.currentIndex,
  });

  void _onNavBarTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/categories');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/cart');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: appBar,
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.orange.shade100),
              accountName: Text(
                user?.fullName ?? 'User',
                style: TextStyle(color: Colors.orange.shade900),
              ),
              accountEmail: Text(
                user?.email ?? '',
                style: TextStyle(color: Colors.orange.shade700),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.orange.shade300,
                radius: 30,
                child: user?.profilePictureUrl != null && user!.profilePictureUrl!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.profilePictureUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          errorWidget: (context, url, error) => Text(
                            (user.firstName.substring(0, 1) ?? 'U').toUpperCase(),
                            style: const TextStyle(fontSize: 30, color: Colors.white),
                          ),
                        ),
                      )
                    : Text(
                        (user?.firstName.substring(0, 1) ?? 'U').toUpperCase(),
                        style: const TextStyle(fontSize: 30, color: Colors.white),
                      ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // FIX: Pass context to the helper method
                  _drawerItem(context, Icons.person_outline, 'Profile', Colors.orange.shade800),
                  _drawerItem(context, Icons.shopping_bag_outlined, 'My Orders', Colors.orange.shade800),
                  _drawerItem(context, Icons.list_alt_outlined, 'Shopping Lists', Colors.orange.shade800),
                  _drawerItem(context, Icons.location_on_outlined, 'Addresses', Colors.orange.shade800),
                  _drawerItem(context, Icons.payment_outlined, 'Payment Methods', Colors.orange.shade800),
                  Divider(color: Colors.orange.shade200),
                  _drawerItem(context, Icons.settings_outlined, 'Settings', Colors.orange.shade800),
                  _drawerItem(context, Icons.help_outline, 'Help & Support', Colors.orange.shade800),
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.orange.shade800),
                    title: const Text('Logout', style: TextStyle(color: Colors.black87)),
                    onTap: () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) => _onNavBarTap(context, index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // FIX: Accept BuildContext as a parameter
  Widget _drawerItem(BuildContext context, IconData icon, String label, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: Colors.black87)),
      onTap: () {
        // Close drawer first
        Navigator.pop(context);

        // Navigate based on label
        if (label == 'Profile') {
          Navigator.pushReplacementNamed(context, '/profile');
        } else if (label == 'Payment Methods') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SavedPaymentMethodsScreen(),
            ),
          );
        } else if (label == 'My Orders') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrdersScreen(),
            ),
          );
        } else if (label == 'Shopping Lists') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ShoppingListsScreen(),
            ),
          );
        } else if (label == 'Settings') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
          );
        } else if (label == 'Help & Support') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HelpSupportScreen(),
            ),
          );
        }
        // Add other navigation handlers here as needed
      },
    );
  }
}