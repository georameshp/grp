import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/rbac/roles.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/family/family_service.dart';
import 'package:grp/models/grp_models.dart';

final familyServiceProvider = Provider<FamilyService>((ref) => FamilyService());

/// Families of the signed-in user.
final familiesProvider = StreamProvider<List<Family>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const <Family>[]);
  return ref.watch(familyServiceProvider).familiesOf(user.uid);
});

/// Currently selected family id (null until families load).
final selectedFamilyIdProvider = StateProvider<String?>((ref) => null);

/// Members of the selected family.
final membersProvider = StreamProvider<List<FamilyMember>>((ref) {
  final fid = ref.watch(selectedFamilyIdProvider);
  if (fid == null) return Stream.value(const <FamilyMember>[]);
  return ref.watch(familyServiceProvider).members(fid);
});

/// Pending email invites of the selected family.
final invitesProvider = StreamProvider<List<FamilyInvite>>((ref) {
  final fid = ref.watch(selectedFamilyIdProvider);
  if (fid == null) return Stream.value(const <FamilyInvite>[]);
  return ref.watch(familyServiceProvider).invites(fid);
});

/// Role of the signed-in user inside the selected family (null if unknown).
final myRoleProvider = Provider<FamilyRole?>((ref) {
  final user = ref.watch(currentUserProvider);
  final members = ref.watch(membersProvider).valueOrNull;
  if (user == null || members == null) return null;
  for (final m in members) {
    if (m.uid == user.uid) return m.role;
  }
  return null;
});
