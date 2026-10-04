import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/notifications/reminder_service.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/children/children_providers.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/features/todos/todos_providers.dart';
import 'package:intl/intl.dart';

/// Todo list with open/done filters, add dialog, toggle + delete.
/// A local reminder fires at 9:00 on the due date (scheduled on-device).
class TodosScreen extends ConsumerWidget {
  const TodosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fid = ref.watch(selectedFamilyIdProvider);
    final todosAsync = ref.watch(todosProvider);
    final filtered = ref.watch(filteredTodosProvider);
    final filter = ref.watch(todoFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Todos')),
      floatingActionButton: fid == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showAdd(context, ref),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          if (fid == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Create or select a family first (Family tab), then plan activities here.',
                textAlign: TextAlign.center,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<TodoFilter>(
                segments: const [
                  ButtonSegment(
                    value: TodoFilter.all,
                    label: Text('All'),
                  ),
                  ButtonSegment(
                    value: TodoFilter.open,
                    label: Text('Open'),
                  ),
                  ButtonSegment(
                    value: TodoFilter.done,
                    label: Text('Done'),
                  ),
                ],
                selected: {filter},
                onSelectionChanged: (s) =>
                    ref.read(todoFilterProvider.notifier).state = s.first,
              ),
            ),
          Expanded(
            child: todosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load todos: $e')),
              data: (_) {
                if (fid == null) return const SizedBox.shrink();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Nothing here. Tap + to add your first todo.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    return Card(
                      child: CheckboxListTile(
                        value: t.done,
                        onChanged: (v) async {
                          await ref
                              .read(todoServiceProvider)
                              .toggle(fid, t, v ?? false);
                          if (v == true) {
                            await ReminderService.instance
                                .cancelTodo(reminderIdFor(t.id!));
                          }
                        },
                        title: Text(
                          t.title,
                          style: TextStyle(
                            decoration:
                                t.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (t.dueAt != null)
                              'Due ${DateFormat.yMMMd().format(t.dueAt!)}',
                            if (t.notes.isNotEmpty) t.notes,
                            t.scope,
                          ].join(' · '),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ReminderService.instance
                                .cancelTodo(reminderIdFor(t.id!));
                            await ref
                                .read(todoServiceProvider)
                                .remove(fid, t.id!);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdd(BuildContext context, WidgetRef ref) async {
    final fid = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (fid == null || user == null) return;
    final kids = ref.read(childrenProvider).valueOrNull ?? [];
    final title = TextEditingController();
    final notes = TextEditingController();
    DateTime? due;
    String scope = 'personal';
    String? childId = kids.isNotEmpty ? kids.first.id : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('New todo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      due == null
                          ? 'No due date'
                          : 'Due ${DateFormat.yMMMd().format(due!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) setDialog(() => due = picked);
                    },
                    child: const Text('Pick date'),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: scope,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: [
                  const DropdownMenuItem(
                    value: 'personal',
                    child: Text('Personal'),
                  ),
                  const DropdownMenuItem(
                    value: 'family',
                    child: Text('Family — shared'),
                  ),
                  if (kids.isNotEmpty)
                    const DropdownMenuItem(
                      value: 'child',
                      child: Text('Child — study/task'),
                    ),
                ],
                onChanged: (v) => setDialog(() => scope = v ?? 'personal'),
              ),
              if (scope == 'child' && kids.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: childId,
                  decoration:
                      const InputDecoration(labelText: 'Child'),
                  items: [
                    for (final k in kids)
                      DropdownMenuItem(
                        value: k.id,
                        child: Text(k.name),
                      ),
                  ],
                  onChanged: (v) => setDialog(() => childId = v),
                ),
              if (due != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'A reminder will fire on this device at 9:00 on the due date.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final titleText = title.text;
    final notesText = notes.text;
    title.dispose();
    notes.dispose();
    if (ok != true || titleText.trim().isEmpty) return;
    final id = await ref.read(todoServiceProvider).add(
          familyId: fid,
          createdBy: user.uid,
          title: titleText,
          notes: notesText,
          dueAt: due,
          scope: scope,
          childId: scope == 'child' ? childId : null,
        );
    if (due != null) {
      await ReminderService.instance.scheduleTodo(
        id: reminderIdFor(id),
        title: titleText.trim(),
        dueAt: due,
      );
    }
  }
}
