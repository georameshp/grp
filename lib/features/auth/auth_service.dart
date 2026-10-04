import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';

/// Friendly wrapper so UI never has to parse Firebase error codes.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  AuthService({FirebaseAuth? auth, GoogleSignIn? google})
      : _auth = auth ?? FirebaseAuth.instance,
        _google = google ?? GoogleSignIn();

  Stream<User?> authState() {
    if (!FirebaseBootstrap.isReady) return const Stream.empty();
    return _auth.authStateChanges();
  }

  User? get currentUser =>
      FirebaseBootstrap.isReady ? _auth.currentUser : null;

  void _requireReady() {
    if (!FirebaseBootstrap.isReady) {
      throw const AuthException(
        'Firebase is not connected yet. Run `flutterfire configure` first.',
      );
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    _requireReady();
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await ensureUserDoc(cred.user!);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<UserCredential> registerWithEmail(
    String name,
    String email,
    String password,
  ) async {
    _requireReady();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(name.trim());
      await ensureUserDoc(cred.user!, displayName: name.trim());
      // Firebase confirmation link (the Gmail welcome mail is queued by
      // the onUserCreate Function and sent by the GitHub Action mailer).
      // Neither blocks registration.
      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {
        // Offline or not configured — user can resend later.
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    _requireReady();
    try {
      final account = await _google.signIn();
      if (account == null) {
        throw const AuthException('Google sign-in was cancelled.');
      }
      final googleAuth = await account.authentication;
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      await ensureUserDoc(cred.user!);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<void> signOut() async {
    if (!FirebaseBootstrap.isReady) return;
    await _google.signOut();
    await _auth.signOut();
  }

  /// Sends the Firebase password-reset email. Succeeds silently for
  /// unknown addresses (Firebase does not disclose whether they exist).
  Future<void> sendPasswordReset(String email) async {
    _requireReady();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// Re-sends the email-verification link. Returns true when an email was
  /// actually sent, false when the address is already verified.
  Future<bool> resendVerification() async {
    _requireReady();
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('You are not signed in.');
    }
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null) {
      throw const AuthException('You are not signed in.');
    }
    if (fresh.emailVerified) return false;
    try {
      await fresh.sendEmailVerification();
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  /// Reloads the user and returns the current email-verified flag
  /// (null when signed out or Firebase is unconfigured).
  Future<bool?> refreshVerification() async {
    if (!FirebaseBootstrap.isReady) return null;
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    return _auth.currentUser?.emailVerified;
  }

  /// Creates `users/{uid}` on first login. The `onUserCreate` Cloud Function
  /// mirrors the email into `usersByEmail/` for the invite flow.
  Future<void> ensureUserDoc(User user, {String? displayName}) async {
    final ref =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final email = (user.email ?? '').toLowerCase();
    await ref.set({
      'emailLower': email,
      'displayName': displayName ?? user.displayName ?? email.split('@').first,
      'photoUrl': user.photoURL,
      'familyIds': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email. Try signing in.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and retry.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes and try again.';
      default:
        return 'Authentication failed ($code).';
    }
  }
}
