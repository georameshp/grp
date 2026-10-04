import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:http/http.dart' as http;

/// File uploads via Cloudflare R2 (free tier, zero egress fees).
/// Flow: `getUploadUrl` callable (auth-checked, presigned locally in the
/// Function) -> HTTP PUT bytes straight to R2. Files never pass through
/// Firebase, so no Blaze plan is needed.
class R2UploadException implements Exception {
  final String message;
  const R2UploadException(this.message);
  @override
  String toString() => message;
}

class R2StorageService {
  static const int maxBytes = 15 * 1024 * 1024;

  static const _mimeByExt = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
  };

  String mimeFor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return _mimeByExt[ext] ?? 'application/octet-stream';
  }

  /// Uploads bytes and returns the public R2 URL.
  Future<String> upload({
    String? familyId,
    required String kind,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (!FirebaseBootstrap.isReady) {
      throw const R2UploadException('Firebase is not connected yet.');
    }
    if (bytes.length > maxBytes) {
      throw const R2UploadException('File is too large (max 15 MB).');
    }
    final contentType = mimeFor(filename);
    late Map<String, dynamic> urls;
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('getUploadUrl');
      final res = await fn.call({
        'familyId': familyId,
        'kind': kind,
        'filename': filename.split('/').last,
        'contentType': contentType,
      });
      urls = Map<String, dynamic>.from(res.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw R2UploadException(e.message ?? 'Could not start upload.');
    }
    final put = await http.put(
      Uri.parse(urls['uploadUrl'] as String),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (put.statusCode < 200 || put.statusCode >= 300) {
      debugPrint('[GRP] R2 PUT failed: ${put.statusCode}');
      throw const R2UploadException('Upload failed. Try again.');
    }
    return urls['publicUrl'] as String;
  }
}
