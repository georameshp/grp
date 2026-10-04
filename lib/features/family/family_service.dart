import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:grp/core/rbac/roles.dart';
import 'package:grp/models/grp_models.dart';

class FamilyException implements Exception {
  final String message;
  const FamilyException(this.message);
  @override
  String toString() => message;
}

/// A row in `families/{fid}/members/{uid}`.
class FamilyMember {
  final String uid;
  final FamilyRole role;
  final String invitedEmail;
  final String status; // active | invited
  final List<String> assignedChildIds;

  const FamilyMember({
    required this.uid,
    required this.role,
    this.invitedEmail = '',
    this.status = 'active',
    this.assignedChildIds = const [],
  });

  factory FamilyMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FamilyMember(
      uid: doc.id,
      role: familyRoleFromString(d['role'] as String?),
      invitedEmail: d['invitedEmail'] as String? ?? '',
      status: d['status'] as String? ?? 'active',
      assignedChildIds: List<String>.from(d['assignedChildIds'] ?? []),
    );
  }
}

/// A pending email invite in `families/{fid}/invites/{hash}`.
class FamilyInvite {
  final String id;
  final String email;
  final String role;

  const FamilyInvite({required this.id, required this.email, required this.role});

  factory FamilyInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FamilyInvite(
      id: doc.id,
      email: d['invitedEmail'] as String? ?? '',
      role: d['role'] as String? ?? 'child',
    );
  }
}

class FamilyService {
  final FirebaseFirestore _db;
  FamilyService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _families =>
      _db.collection(Family.collection);

  bool get _ready => FirebaseBootstrap.isReady;

  /// Families the user belongs to (via `users/{uid}.familyIds`).
  Stream<List<Family>> familiesOf(String uid) {
    if (!_ready) return Stream.value(const []);
    return _db.doc('users/$uid').snapshots().asyncMap((snap) async {
      final ids = List<String>.from((snap.data()?['familyIds'] ?? []));
      if (ids.isEmpty) return const <Family>[];
      final docs = await Future.wait(
        ids.map((id) => _families.doc(id).get()),
      );
      return [
        for (final d in docs)
          if (d.exists) Family.fromDoc(d),
      ];
    });
  }

  Stream<List<FamilyMember>> members(String familyId) {
    if (!_ready) return Stream.value(const []);
    return _families
        .doc(familyId)
        .collection(Family.membersSub)
        .snapshots()
        .map((s) => s.docs.map(FamilyMember.fromDoc).toList());
  }

  Stream<List<FamilyInvite>> invites(String familyId) {
    if (!_ready) return Stream.value(const []);
    return _families
        .doc(familyId)
        .collection('invites')
        .snapshots()
        .map((s) => s.docs.map(FamilyInvite.fromDoc).toList());
  }

  /// Creates a family and bootstraps the caller as owner.
  Future<String> createFamily({required String name, required String uid}) async {
    if (!_ready) {
      throw const FamilyException('Firebase is not connected yet.');
    }
    final famRef = _families.doc();
    final batch = _db.batch();
    batch.set(famRef, {
      'name': name.trim(),
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(famRef.collection(Family.membersSub).doc(uid), {
      'role': FamilyRole.owner.name,
      'status': 'active',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.doc('users/$uid'), {
      'familyIds': FieldValue.arrayUnion([famRef.id]),
    });
    await batch.commit();
    return famRef.id;
  }

  /// Invites by email via the `inviteMember` Callable Function, which checks
  /// `usersByEmail` first: existing users join instantly, new emails get a
  /// pending invite (re-invite after they sign up to add them instantly).
  /// The invite email is queued by the Function and sent by the mailer.
  Future<String> inviteByEmail({
    required String familyId,
    required String email,
    required FamilyRole role,
    List<String> assignedChildIds = const [],
  }) async {
    if (!_ready) {
      throw const FamilyException('Firebase is not connected yet.');
    }
    try {
      final fn =
          FirebaseFunctions.instance.httpsCallable('inviteMember');
      final res = await fn.call({
        'familyId': familyId,
        'email': email.trim().toLowerCase(),
        'role': role.name,
        'assignedChildIds': assignedChildIds,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['invited'] == true) {
        return 'Invite sent to ${email.trim()}. They will join after signing up with this email (then invite again to add instantly).';
      }
      return '${email.trim()} added to the family.';
    } on FirebaseFunctionsException catch (e) {
      throw FamilyException(e.message ?? 'Invite failed (${e.code}).');
    }
  }
}
