import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import 'qr_code_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          Card(
            child: Column(
              children: [
                // Theme Mode
                ListTile(
                  leading: Icon(Icons.brightness_6, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Theme Mode'),
                  subtitle: Text(themeProvider.themeModeDisplay),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeModeDialog(context, themeProvider),
                ),
                const Divider(height: 1),
                // Luminosity
                ListTile(
                  leading: Icon(Icons.brightness_4, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Luminosity'),
                  subtitle: Text(themeProvider.luminosityDisplay),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLuminosityDialog(context, themeProvider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Shopping Lists Section
          _buildSectionHeader('Shopping Lists'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.qr_code, color: Theme.of(context).colorScheme.primary),
                  title: const Text('QR Code for Shopping Lists'),
                  subtitle: const Text('Generate QR codes to share your shopping lists'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QRCodeScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader('Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Profile'),
                  subtitle: Text(authProvider.user?.email ?? 'Not logged in'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/profile');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.notifications, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to terms of service
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.privacy_tip, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to privacy policy
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeModeOption.values.map((mode) {
            return RadioListTile<ThemeModeOption>(
              title: Text(_getThemeModeLabel(mode)),
              value: mode,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLuminosityDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Luminosity Level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LuminosityLevel.values.map((level) {
            return RadioListTile<LuminosityLevel>(
              title: Text(_getLuminosityLabel(level)),
              value: level,
              groupValue: themeProvider.luminosity,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setLuminosity(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getThemeModeLabel(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.light:
        return 'Light';
      case ThemeModeOption.dark:
        return 'Dark';
      case ThemeModeOption.system:
        return 'System Default';
    }
  }

  String _getLuminosityLabel(LuminosityLevel level) {
    switch (level) {
      case LuminosityLevel.low:
        return 'Low (70%)';
      case LuminosityLevel.medium:
        return 'Medium (100%)';
      case LuminosityLevel.high:
        return 'High (130%)';
    }
  }
}

