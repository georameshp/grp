/// GRP role model — single source of truth for Firestore rules + client guards.
enum FamilyRole {
  owner,
  parent,
  child,
  teacher,
}

/// Parse helper that never throws on unknown values from Firestore.
FamilyRole familyRoleFromString(String? raw) {
  switch (raw) {
    case 'owner':
      return FamilyRole.owner;
    case 'parent':
      return FamilyRole.parent;
    case 'child':
      return FamilyRole.child;
    case 'teacher':
      return FamilyRole.teacher;
    default:
      return FamilyRole.child;
  }
}

extension FamilyRoleX on FamilyRole {
  String get name => toString().split('.').last;

  /// Full read/write inside the family workspace.
  bool get isManager => this == FamilyRole.owner || this == FamilyRole.parent;

  /// Scoped to assigned children only (enforced in rules + queries).
  bool get isTeacher => this == FamilyRole.teacher;
}
