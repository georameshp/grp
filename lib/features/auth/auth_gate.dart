import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';

/// Watches Firebase Auth state. If Firebase is unconfigured (Phase 0),
/// falls through to [child] so the Rive template still runs.
final authStateProvider = StreamProvider<User?>((ref) {
  if (!FirebaseBootstrap.isReady) return const Stream.empty();
  return FirebaseAuth.instance.authStateChanges();
});

class AuthGate extends ConsumerWidget {
  final Widget signedOutChild;
  final Widget signedInChild;
  const AuthGate({
    super.key,
    required this.signedOutChild,
    required this.signedInChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FirebaseBootstrap.isReady) return signedOutChild;
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) => user == null ? signedOutChild : signedInChild,
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => signedOutChild,
    );
  }
}
