import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/children/children_providers.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/models/tuition_models.dart';
import 'package:intl/intl.dart';

/// Child profiles. Managers add/remove; teachers see assigned children only.
class ChildrenScreen extends ConsumerStatefulWidget {
  const ChildrenScreen({super.key});

  @override
  ConsumerState<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends ConsumerState<ChildrenScreen> {
  final _name = TextEditingController();
  final _school = TextEditingController();
  final _subjects = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final fid = ref.read(selectedFamilyIdProvider);
    if (fid == null || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(childrenServiceProvider).addChild(
            familyId: fid,
            child: ChildProfile(
              name: _name.text.trim(),
              school: _school.text.trim(),
              subjects: _subjects.text
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
            ),
          );
      _name.clear();
      _school.clear();
      _subjects.clear();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showAdd() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add child'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _school,
              decoration: const InputDecoration(labelText: 'School'),
            ),
            TextField(
              controller: _subjects,
              decoration: const InputDecoration(
                labelText: 'Subjects (comma separated)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _add,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fid = ref.watch(selectedFamilyIdProvider);
    final kidsAsync = ref.watch(childrenProvider);
    final visible = ref.watch(visibleChildrenProvider);
    final myRole = ref.watch(myRoleProvider);
    final canManage = myRole == null || myRole.isManager;

    return Scaffold(
      appBar: AppBar(title: const Text('Children')),
      floatingActionButton: fid == null || !canManage
          ? null
          : FloatingActionButton(
              onPressed: _showAdd,
              child: const Icon(Icons.add),
            ),
      body: fid == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Create or select a family first (Family tab).',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : kidsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load children: $e')),
              data: (_) {
                if (visible.isEmpty) {
                  return Center(
                    child: Text(
                      canManage
                          ? 'No children yet. Tap + to add one.'
                          : 'No children assigned to you yet.',
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final c = visible[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            c.name.isNotEmpty
                                ? c.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                          [
                            if (c.school.isNotEmpty) c.school,
                            if (c.subjects.isNotEmpty)
                              c.subjects.join(', '),
                          ].join(' · '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canManage)
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => ref
                                    .read(childrenServiceProvider)
                                    .removeChild(fid, c.id!),
                              ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => context.push('/children/${c.id}'),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Daily activity + study log for one child.
class ChildDetailScreen extends ConsumerStatefulWidget {
  final String childId;
  const ChildDetailScreen({super.key, required this.childId});

  @override
  ConsumerState<ChildDetailScreen> createState() =>
      _ChildDetailScreenState();
}

class _ChildDetailScreenState extends ConsumerState<ChildDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final fid = ref.watch(selectedFamilyIdProvider);
    final kids = ref.watch(childrenProvider).valueOrNull ?? [];
    ChildProfile? child;
    for (final k in kids) {
      if (k.id == widget.childId) child = k;
    }
    if (fid == null || child == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Child')),
        body: const Center(child: Text('Child not found.')),
      );
    }
    final activities = ref.watch(
      _activitiesProvider((familyId: fid, childId: widget.childId)),
    );
    final totalHours = activities.valueOrNull
            ?.fold<double>(0, (s, a) => s + a.studyHours) ??
        0;

    return Scaffold(
      appBar: AppBar(title: Text(child.name)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _logActivity(fid, widget.childId),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (child.school.isNotEmpty) Text('School: ${child.school}'),
                  if (child.subjects.isNotEmpty)
                    Text('Subjects: ${child.subjects.join(', ')}'),
                  Text(
                    'Total study logged: ${totalHours.toStringAsFixed(1)} hrs',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Daily log',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          activities.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Could not load log: $e'),
            data: (items) => Column(
              children: [
                for (final a in items)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          a.studyHours.toStringAsFixed(0),
                        ),
                      ),
                      title: Text(
                        a.schoolLog.isEmpty ? 'Study session' : a.schoolLog,
                      ),
                      subtitle: Text(
                        '${DateFormat.yMMMd().format(a.date)} · ${a.studyHours.toStringAsFixed(1)} hrs'
                        '${a.mood.isNotEmpty ? ' · ${a.mood}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => ref
                            .read(childrenServiceProvider)
                            .removeActivity(fid, widget.childId, a.id!),
                      ),
                    ),
                  ),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No entries yet. Tap + to log a day.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logActivity(String fid, String childId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final log = TextEditingController();
    final hours = TextEditingController();
    String mood = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Log a day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: log,
                decoration: const InputDecoration(
                  labelText: 'School / study notes',
                ),
              ),
              TextField(
                controller: hours,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Study hours (e.g. 2.5)',
                ),
              ),
              DropdownButtonFormField<String>(
                value: mood.isEmpty ? null : mood,
                decoration: const InputDecoration(labelText: 'Mood'),
                items: const [
                  DropdownMenuItem(value: 'great', child: Text('Great')),
                  DropdownMenuItem(value: 'ok', child: Text('OK')),
                  DropdownMenuItem(value: 'tired', child: Text('Tired')),
                ],
                onChanged: (v) => setDialog(() => mood = v ?? ''),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final parsed = double.tryParse(hours.text.trim()) ?? 0;
    final logText = log.text;
    log.dispose();
    hours.dispose();
    if (ok != true) return;
    await ref.read(childrenServiceProvider).logActivity(
          familyId: fid,
          childId: childId,
          activity: ChildActivity(
            date: DateTime.now(),
            schoolLog: logText.trim(),
            studyHours: parsed,
            mood: mood,
          ),
          uid: user.uid,
        );
  }
}

typedef _ChildKey = ({String familyId, String childId});

final _activitiesProvider =
    StreamProvider.family<List<ChildActivity>, _ChildKey>((ref, key) {
  return ref
      .watch(childrenServiceProvider)
      .activities(key.familyId, key.childId);
});
