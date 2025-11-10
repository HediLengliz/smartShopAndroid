import 'package:flutter/material.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final List<FAQItem> _faqs = [
    FAQItem(
      question: 'How do I create a shopping list?',
      answer: 'To create a shopping list, go to the Shopping Lists section from the sidebar menu, then tap the "+" button. You can add products by searching for them or using templates.',
    ),
    FAQItem(
      question: 'How do I share my shopping list?',
      answer: 'You can share your shopping list by generating a QR code. Go to Settings > QR Code for Shopping Lists, select your list, and share the QR code with others.',
    ),
    FAQItem(
      question: 'How do I add items to my cart from a shopping list?',
      answer: 'Open your shopping list and tap the "Add to Cart" button at the bottom of the card. This will add all items from the list to your cart.',
    ),
    FAQItem(
      question: 'How do I change my payment method?',
      answer: 'Go to the sidebar menu and select "Payment Methods". From there, you can add, edit, or remove payment methods.',
    ),
    FAQItem(
      question: 'How do I track my orders?',
      answer: 'Go to "My Orders" from the sidebar menu to view all your orders and their current status.',
    ),
    FAQItem(
      question: 'How do I enable dark mode?',
      answer: 'Go to Settings > Theme Mode and select "Dark" to enable dark mode. You can also set it to "System" to follow your device settings.',
    ),
    FAQItem(
      question: 'How do I change my profile information?',
      answer: 'Go to your Profile from the bottom navigation bar or sidebar menu, then tap "Edit Profile" to update your information.',
    ),
    FAQItem(
      question: 'What payment methods are accepted?',
      answer: 'We accept all major credit cards, debit cards, and digital payment methods through Stripe.',
    ),
    FAQItem(
      question: 'How do I report a bug?',
      answer: 'Go to Help & Support > Report a Bug to submit a bug report. Our team will review it and get back to you.',
    ),
    FAQItem(
      question: 'How do I contact customer support?',
      answer: 'You can contact us through the Help & Support section, email us at support@smartshop.com, or call us at +1 (555) 123-4567.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frequently Asked Questions'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          return _FAQCard(faq: _faqs[index]);
        },
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });
}

class _FAQCard extends StatefulWidget {
  final FAQItem faq;

  const _FAQCard({required this.faq});

  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          widget.faq.question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.faq.answer,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

