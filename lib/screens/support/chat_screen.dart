import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  late String _sessionId;
  SharedPreferences? _prefs;

  static const String _storageMessagesKey = 'smartshop_chat_messages';
  static const String _storageSessionKey = 'smartshop_chat_session';

  @override
  void initState() {
    super.initState();
    _sessionId = _generateSessionId();
    _loadConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _generateSessionId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _loadConversation() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final storedSession = _prefs?.getString(_storageSessionKey);
      final storedMessages = _prefs?.getString(_storageMessagesKey);

      if (storedSession != null && storedSession.isNotEmpty) {
        _sessionId = storedSession;
      } else {
        await _prefs?.setString(_storageSessionKey, _sessionId);
      }

      if (storedMessages != null && storedMessages.isNotEmpty) {
        final decoded = jsonDecode(storedMessages);
        if (decoded is List) {
          final restored = decoded
              .whereType<Map<String, dynamic>>()
              .map(_ChatMessage.fromJson)
              .toList();
          if (restored.isNotEmpty) {
            setState(() {
              _messages
                ..clear()
                ..addAll(restored);
            });
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load chat history: $e');
    }
  }

  Future<void> _persistConversation() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(_messages.map((message) => message.toJson()).toList());
      await _prefs?.setString(_storageMessagesKey, encoded);
      await _prefs?.setString(_storageSessionKey, _sessionId);
    } catch (e) {
      debugPrint('Failed to persist chat history: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(content: text, fromUser: true));
      _isSending = true;
      _messageController.clear();
    });
    _scrollToBottom();
    await _persistConversation();

    try {
      final uri = Uri.parse(ApiConfig.chatEndpoint);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': _sessionId,
          'userMessage': text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = (data['reply'] as String?)?.trim();
        setState(() {
          _messages.add(
            _ChatMessage(
              content: reply?.isNotEmpty == true
                  ? reply!
                  : 'Sorry, I could not process that right now.',
              fromUser: false,
            ),
          );
        });
        await _persistConversation();
      } else {
        setState(() {
          _messages.add(
            const _ChatMessage(
              content: 'Sorry, I ran into an issue. Please try again later.',
              fromUser: false,
            ),
          );
        });
        await _persistConversation();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage(
            content: 'Network error. Please check your connection.',
            fromUser: false,
          ),
        );
      });
      await _persistConversation();
    } finally {
      if (!mounted) return;
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  Future<void> _clearConversation() async {
    final previousSession = _sessionId;
    setState(() {
      _messages.clear();
      _sessionId = _generateSessionId();
    });
    _scrollToBottom();
    await _persistConversation();

    try {
      await http.post(
        Uri.parse('${ApiConfig.chatEndpoint}/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sessionId': previousSession}),
      );
    } catch (e) {
      debugPrint('Failed to reset chat session: $e');
    }
  }

  Future<void> _confirmClearConversation() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text('This will remove the current chat history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      await _clearConversation();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF16171A),
        title: const Text('SmartShop Assistant'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear conversation',
            onPressed: _isSending ? null : _confirmClearConversation,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isSending && index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _TypingIndicator(),
                    ),
                  );
                }
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF16171A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ask about SmartShop...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: const Color(0xFF1F1F23),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF00D26A),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.black),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String content;
  final bool fromUser;

  const _ChatMessage({
    required this.content,
    required this.fromUser,
  });

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
        content: json['content'] as String? ?? '',
        fromUser: json['fromUser'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        'fromUser': fromUser,
      };
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor =
        message.fromUser ? const Color(0xFF00D26A) : const Color(0xFF1F1F23);
    final textColor = message.fromUser ? Colors.black : Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.content,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Dot(delay: Duration(milliseconds: 0)),
          _Dot(delay: Duration(milliseconds: 150)),
          _Dot(delay: Duration(milliseconds: 300)),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Duration delay;

  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _animation = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward(from: 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF00D26A),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

