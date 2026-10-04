import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/children/children_providers.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/models/grp_models.dart';

class TodoService {
  final FirebaseFirestore _db;
  TodoService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String familyId) => _db
      .collection(Family.collection)
      .doc(familyId)
      .collection(TodoItem.sub);

  bool get _ready => FirebaseBootstrap.isReady;

  Stream<List<TodoItem>> todos(String familyId) {
    if (!_ready) return Stream.value(const []);
    return _col(familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TodoItem.fromDoc).toList());
  }

  /// Adds a todo and returns its doc id (used for reminder scheduling).
  Future<String> add({
    required String familyId,
    required String createdBy,
    required String title,
    String notes = '',
    DateTime? dueAt,
    String scope = 'personal',
    String? childId,
    List<String> assigneeUids = const [],
  }) async {
    final ref = await _col(familyId).add(TodoItem(
      title: title.trim(),
      notes: notes.trim(),
      dueAt: dueAt,
      remindAt: dueAt,
      scope: scope,
      childId: childId,
      assigneeUids: assigneeUids,
    ).toJson(createdBy));
    return ref.id;
  }

  Future<void> toggle(String familyId, TodoItem todo, bool done) =>
      _col(familyId).doc(todo.id).update({'done': done});

  Future<void> remove(String familyId, String id) =>
      _col(familyId).doc(id).delete();
}

final todoServiceProvider = Provider<TodoService>((ref) => TodoService());

/// Todos of the selected family (empty when none selected).
final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final fid = ref.watch(selectedFamilyIdProvider);
  if (fid == null) return Stream.value(const <TodoItem>[]);
  return ref.watch(todoServiceProvider).todos(fid);
});

enum TodoFilter { all, open, done }

final todoFilterProvider = StateProvider<TodoFilter>((ref) => TodoFilter.all);

/// Filtered view for the list UI. Teachers only see todos for their
/// assigned children (plus ones explicitly assigned to them).
final filteredTodosProvider = Provider<List<TodoItem>>((ref) {
  final filter = ref.watch(todoFilterProvider);
  var todos = ref.watch(todosProvider).valueOrNull ?? [];
  final role = ref.watch(myRoleProvider);
  if (role != null && role.isTeacher) {
    final visible = ref.watch(visibleChildIdsProvider) ?? [];
    final uid = ref.watch(currentUserProvider)?.uid;
    todos = todos
        .where((t) =>
            (t.childId != null && visible.contains(t.childId)) ||
            t.assigneeUids.contains(uid))
        .toList();
  }
  switch (filter) {
    case TodoFilter.all:
      return todos;
    case TodoFilter.open:
      return todos.where((t) => !t.done).toList();
    case TodoFilter.done:
      return todos.where((t) => t.done).toList();
  }
});
