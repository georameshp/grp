import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/features/family/family_service.dart';
import 'package:grp/models/grp_models.dart';
import 'package:grp/models/tuition_models.dart';

/// Teacher member row joined with their `teachers/{uid}` profile.
class TeacherWithProfile {
  final FamilyMember member;
  final TeacherProfile profile;
  const TeacherWithProfile({required this.member, required this.profile});

  double due(List<TuitionSession> sessions) => paymentDue(sessions);
}

class TuitionService {
  final FirebaseFirestore _db;
  TuitionService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _teachers(String familyId) => _db
      .collection(Family.collection)
      .doc(familyId)
      .collection(TeacherProfile.sub);

  bool get _ready => FirebaseBootstrap.isReady;

  /// Teachers = family members with role teacher, merged with rate profiles.
  Stream<List<TeacherWithProfile>> teachers(String familyId) {
    if (!_ready) return Stream.value(const []);
    return _db
        .collection(Family.collection)
        .doc(familyId)
        .collection(Family.membersSub)
        .snapshots()
        .asyncMap((snap) async {
      final out = <TeacherWithProfile>[];
      for (final m in snap.docs.map(FamilyMember.fromDoc)) {
        if (m.role.name != 'teacher') continue;
        final prof = await _teachers(familyId).doc(m.uid).get();
        out.add(TeacherWithProfile(
          member: m,
          profile: prof.exists
              ? TeacherProfile.fromDoc(prof)
              : TeacherProfile(
                  userId: m.uid,
                  email: m.invitedEmail,
                  assignedChildIds: m.assignedChildIds,
                ),
        ));
      }
      return out;
    });
  }

  Stream<List<TuitionSession>> sessions(String familyId, String teacherId) {
    if (!_ready) return Stream.value(const []);
    return _teachers(familyId)
        .doc(teacherId)
        .collection(TuitionSession.sub)
        .orderBy('start', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TuitionSession.fromDoc).toList());
  }

  Future<void> saveProfile({
    required String familyId,
    required String teacherId,
    required TeacherProfile profile,
  }) =>
      _teachers(familyId).doc(teacherId).set(profile.toJson(), SetOptions(merge: true));

  Future<void> logSession({
    required String familyId,
    required String teacherId,
    required TuitionSession session,
    required String loggedBy,
  }) async {
    await _teachers(familyId)
        .doc(teacherId)
        .collection(TuitionSession.sub)
        .add(session.toJson(loggedBy));
  }
  Future<void> assignChildren({
    required String familyId,
    required String teacherId,
    required List<String> childIds,
  }) =>
      _db
          .collection(Family.collection)
          .doc(familyId)
          .collection(Family.membersSub)
          .doc(teacherId)
          .update({'assignedChildIds': childIds});

  Future<void> setStatus({
    required String familyId,
    required String teacherId,
    required String sessionId,
    required String status,
    String? approvedBy,
  }) =>
      _teachers(familyId)
          .doc(teacherId)
          .collection(TuitionSession.sub)
          .doc(sessionId)
          .update({'status': status, 'approvedBy': approvedBy});
}

final tuitionServiceProvider =
    Provider<TuitionService>((ref) => TuitionService());

final teachersProvider = StreamProvider<List<TeacherWithProfile>>((ref) {
  final fid = ref.watch(selectedFamilyIdProvider);
  if (fid == null) return Stream.value(const <TeacherWithProfile>[]);
  return ref.watch(tuitionServiceProvider).teachers(fid);
});

final sessionsProvider = StreamProvider.family<List<TuitionSession>, String>(
    (ref, teacherId) {
  final fid = ref.watch(selectedFamilyIdProvider);
  if (fid == null) return Stream.value(const <TuitionSession>[]);
  return ref.watch(tuitionServiceProvider).sessions(fid, teacherId);
});
