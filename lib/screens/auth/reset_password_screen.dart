import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? token;

  const ResetPasswordScreen({super.key, this.email, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String? _error;
  bool _submitting = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email ?? '';
    _tokenController.text = widget.token ?? '';
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final email = _emailController.text.trim();
    final token = _tokenController.text.trim();
    final pw = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (email.isEmpty || token.isEmpty) {
      setState(() => _error = 'Missing email or token.');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pw != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _submitting = true);
    final result = await AuthService.resetPassword(
      email: email,
      token: token,
      newPassword: pw,
    );
    setState(() => _submitting = false);

    if (result['success'] == true) {
      // Success animation
      await _animController.forward();
      if (!mounted) return;
      // Load user info if available and navigate
      final auth = context.read<AuthProvider>();
      await auth.loadUser();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() => _error = result['message'] ?? 'Reset failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _InfoHeader(),
            const SizedBox(height: 20),

            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
            ),
            const SizedBox(height: 14),

            // Token
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Reset token',
                hintText: 'Paste token from the email link',
              ),
            ),
            const SizedBox(height: 14),

            // New password
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Reset Password'),
            ),

            const SizedBox(height: 28),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
                child: _SuccessBadge(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter the new password for your account',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'The token and email are prefilled if you opened the in-app link.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            // FIX: Use withAlpha on the color for opacity
            // 0.75 opacity = 191 alpha (255 * 0.75)
            color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(191),
          ),
        )
      ],
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      width: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // FIX: Use withAlpha here as well for consistency
        color: Colors.green.withAlpha(30), // .12 opacity = 30 alpha (255 * 0.12)
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: const Icon(Icons.check_rounded, color: Colors.green, size: 44),
    );
  }
}


