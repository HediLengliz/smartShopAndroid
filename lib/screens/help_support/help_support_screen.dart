import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'faq_screen.dart';
import 'review_bug_screen.dart';
import 'chat_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Help Section
          _buildSectionHeader('Quick Help'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Frequently Asked Questions'),
                  subtitle: const Text('Find answers to common questions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FAQScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Community Chat'),
                  subtitle: const Text('Get help from the community'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Feedback Section
          _buildSectionHeader('Feedback'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.star_outline, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Submit a Review'),
                  subtitle: const Text('Share your experience and rate the app'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReviewBugScreen(type: FeedbackType.review),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.bug_report_outlined, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Report a Bug'),
                  subtitle: const Text('Help us improve by reporting issues'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReviewBugScreen(type: FeedbackType.bug),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Contact Section
          _buildSectionHeader('Contact Us'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.email, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Email Support'),
                  subtitle: const Text('support@smartshop.com'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'support@smartshop.com',
                      queryParameters: {
                        'subject': 'Support Request from SmartShop App',
                      },
                    );
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open email client'),
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Phone Support'),
                  subtitle: const Text('+1 (555) 123-4567'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final Uri phoneUri = Uri(
                      scheme: 'tel',
                      path: '+15551234567',
                    );
                    if (await canLaunchUrl(phoneUri)) {
                      await launchUrl(phoneUri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open phone dialer'),
                          ),
                        );
                      }
                    }
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
}

