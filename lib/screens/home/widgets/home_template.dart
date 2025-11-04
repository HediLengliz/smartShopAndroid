import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/auth_provider.dart';

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
                child: Text(
                  (user?.firstName.substring(0, 1) ?? 'U').toUpperCase(),
                  style: const TextStyle(fontSize: 30, color: Colors.white),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(Icons.person_outline, 'Profile', Colors.orange.shade800),
                  _drawerItem(Icons.shopping_bag_outlined, 'My Orders', Colors.orange.shade800),
                  _drawerItem(Icons.list_alt_outlined, 'Shopping Lists', Colors.orange.shade800),
                  _drawerItem(Icons.location_on_outlined, 'Addresses', Colors.orange.shade800),
                  _drawerItem(Icons.payment_outlined, 'Payment Methods', Colors.orange.shade800),
                  Divider(color: Colors.orange.shade200),
                  _drawerItem(Icons.settings_outlined, 'Settings', Colors.orange.shade800),
                  _drawerItem(Icons.help_outline, 'Help & Support', Colors.orange.shade800),
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

  Widget _drawerItem(IconData icon, String label, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: Colors.black87)),
      onTap: () {},
    );
  }
}
