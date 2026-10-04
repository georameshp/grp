import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/models/grp_models.dart';
import 'package:grp/models/tuition_models.dart';

class ChildrenService {
  final FirebaseFirestore _db;
  ChildrenService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String familyId) => _db
      .collection(Family.collection)
      .doc(familyId)
      .collection(ChildProfile.sub);

  CollectionReference<Map<String, dynamic>> _activities(
          String familyId, String childId) =>
      _col(familyId).doc(childId).collection(ChildActivity.sub);

  bool get _ready => FirebaseBootstrap.isReady;

  Stream<List<ChildProfile>> children(String familyId) {
    if (!_ready) return Stream.value(const []);
    return _col(familyId)
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map(ChildProfile.fromDoc).toList());
  }

  Stream<List<ChildActivity>> activities(String familyId, String childId) {
    if (!_ready) return Stream.value(const []);
    return _activities(familyId, childId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ChildActivity.fromDoc).toList());
  }

  Future<String> addChild({
    required String familyId,
    required ChildProfile child,
  }) async {
    final ref = await _col(familyId).add(child.toJson());
    return ref.id;
  }

  Future<void> removeChild(String familyId, String childId) =>
      _col(familyId).doc(childId).delete();

  Future<void> logActivity({
    required String familyId,
    required String childId,
    required ChildActivity activity,
    required String uid,
  }) async {
    await _activities(familyId, childId)
        .add(activity.toJson(childId, uid));
  }

  Future<void> removeActivity(
          String familyId, String childId, String activityId) =>
      _activities(familyId, childId).doc(activityId).delete();
}

final childrenServiceProvider =
    Provider<ChildrenService>((ref) => ChildrenService());

final childrenProvider = StreamProvider<List<ChildProfile>>((ref) {
  final fid = ref.watch(selectedFamilyIdProvider);
  if (fid == null) return Stream.value(const <ChildProfile>[]);
  return ref.watch(childrenServiceProvider).children(fid);
});

/// Child ids the signed-in teacher may access (managers see all).
final visibleChildIdsProvider = Provider<List<String>?>((ref) {
  final role = ref.watch(myRoleProvider);
  if (role == null || role.isManager) return null; // null = all
  if (!role.isTeacher) return const <String>[]; // child accounts: none in MVP
  final user = ref.watch(currentUserProvider);
  final members = ref.watch(membersProvider).valueOrNull ?? [];
  for (final m in members) {
    if (m.uid == user?.uid) return m.assignedChildIds;
  }
  return const <String>[];
});

final visibleChildrenProvider = Provider<List<ChildProfile>>((ref) {
  final all = ref.watch(childrenProvider).valueOrNull ?? [];
  final visible = ref.watch(visibleChildIdsProvider);
  if (visible == null) return all;
  return all.where((c) => visible.contains(c.id)).toList();
});
