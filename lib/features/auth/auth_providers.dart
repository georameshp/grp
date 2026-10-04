import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:grp/features/auth/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Raw Firebase auth state (null stream when Firebase is unconfigured).
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  if (!FirebaseBootstrap.isReady) return const Stream.empty();
  return FirebaseAuth.instance.authStateChanges();
});

/// Currently signed-in user, or null.
final currentUserProvider = Provider<User?>((ref) {
  if (!FirebaseBootstrap.isReady) return null;
  return ref.watch(firebaseAuthStateProvider).valueOrNull;
});
