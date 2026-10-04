import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/auth/auth_service.dart';

/// Signed-in user profile: account info, email-verification status with
/// resend, and sign out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool? _verified;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _verified = ref.read(currentUserProvider)?.emailVerified;
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final verified =
          await ref.read(authServiceProvider).refreshVerification();
      setState(() {
        _verified = verified;
        if (verified == true) _notice = 'Email verified. Thank you!';
      });
    } on AuthException catch (e) {
      setState(() => _notice = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final sent = await ref.read(authServiceProvider).resendVerification();
      setState(() {
        _notice = sent
            ? 'Verification email sent. Check your inbox (and spam).'
            : 'Your email is already verified.';
        if (!sent) _verified = true;
      });
    } on AuthException catch (e) {
      setState(() => _notice = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    // Keep in sync if the auth state itself changes (sign in/out).
    final streamVerified = user?.emailVerified;
    if (streamVerified != null && _verified == null) {
      _verified = streamVerified;
    }
    final verified = _verified ?? streamVerified ?? false;
    final isPasswordAccount = user != null &&
        (user.providerData.any((p) => p.providerId == 'password'));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(
            radius: 36,
            child: Text(
              ((user?.displayName ?? user?.email ?? '?').isNotEmpty
                      ? (user?.displayName ?? user?.email ?? '?')[0]
                      : '?')
                  .toUpperCase(),
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'GRP member',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            user?.email ?? 'Not signed in',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          if (user != null)
            Card(
              color: verified
                  ? Colors.green.withOpacity(0.08)
                  : Colors.orange.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          verified
                              ? Icons.verified_outlined
                              : Icons.warning_amber_outlined,
                          color: verified ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            verified
                                ? 'Email verified'
                                : isPasswordAccount
                                    ? 'Email not verified yet'
                                    : 'Email status unknown — tap refresh',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!_busy)
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Refresh status',
                            onPressed: _refreshStatus,
                          ),
                      ],
                    ),
                    if (!verified) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Verify your address to confirm your account and receive family notifications reliably.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _resend,
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text('Resend verification email'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (_notice != null) ...[
            const SizedBox(height: 8),
            Text(
              _notice!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
