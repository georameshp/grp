import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Phase 0 bootstrap. Safe to call before `google-services.json` /
/// `GoogleService-Info.plist` exist — it logs and lets the UI run in
/// "local-only" mode so the template still previews.
class FirebaseBootstrap {
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
      // Offline persistence for todos/finance lists.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      _ready = false;
      debugPrint('[GRP] Firebase not configured yet: $e');
    }
  }
}
