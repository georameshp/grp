import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/children/children_providers.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/features/tuition/tuition_providers.dart';
import 'package:grp/models/tuition_models.dart';
import 'package:intl/intl.dart';

/// Tuition teachers: hourly rates, session log, approve/pay flow and dues.
/// Managers see everything; a signed-in teacher sees only their own card.
class TuitionScreen extends ConsumerWidget {
  const TuitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fid = ref.watch(selectedFamilyIdProvider);
    final teachersAsync = ref.watch(teachersProvider);
    final myRole = ref.watch(myRoleProvider);
    final user = ref.watch(currentUserProvider);
    final isManager = myRole == null || myRole.isManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuition'),
        actions: [
          if (isManager && fid != null)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite a teacher via the Family tab',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Invite teachers from the Family tab with the Teacher role.',
                  ),
                ),
              ),
            ),
        ],
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
          : teachersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load teachers: $e')),
              data: (teachers) {
                var list = teachers;
                if (!isManager && user != null) {
                  list = teachers
                      .where((t) => t.member.uid == user.uid)
                      .toList();
                }
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No tuition teachers yet. Invite one from the Family tab with the Teacher role.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) =>
                      _TeacherCard(teacher: list[i], isManager: isManager),
                );
              },
            ),
    );
  }
}

class _TeacherCard extends ConsumerWidget {
  final TeacherWithProfile teacher;
  final bool isManager;
  const _TeacherCard({required this.teacher, required this.isManager});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions =
        ref.watch(sessionsProvider(teacher.member.uid)).valueOrNull ?? [];
    final due = teacher.due(sessions);
    final kids = ref.watch(childrenProvider).valueOrNull ?? [];
    String childName(String id) {
      for (final k in kids) {
        if (k.id == id) return k.name;
      }
      return 'Child';
    }
    final assigned = teacher.profile.assignedChildIds.isNotEmpty
        ? teacher.profile.assignedChildIds
        : teacher.member.assignedChildIds;

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Text(
            (teacher.profile.name.isNotEmpty
                    ? teacher.profile.name
                    : teacher.member.invitedEmail.isNotEmpty
                        ? teacher.member.invitedEmail
                        : '?')[0]
                .toUpperCase(),
          ),
        ),
        title: Text(
          teacher.profile.name.isNotEmpty
              ? teacher.profile.name
              : teacher.member.invitedEmail.isEmpty
                  ? 'Teacher'
                  : teacher.member.invitedEmail,
        ),
        subtitle: Text(
          '${assigned.map(childName).join(', ')} · ₹${teacher.profile.hourlyRate.toStringAsFixed(0)}/hr · Due ₹${due.toStringAsFixed(0)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () =>
                          _logSession(context, ref, assigned, childName),
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Log session'),
                    ),
                    if (isManager)
                      OutlinedButton.icon(
                        onPressed: () => _editRate(context, ref),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Rate & subjects'),
                      ),
                    if (isManager)
                      OutlinedButton.icon(
                        onPressed: () => _assignChildren(context, ref),
                        icon: const Icon(Icons.group_add_outlined, size: 18),
                        label: const Text('Assign'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final s in sessions)
                  _SessionTile(
                    session: s,
                    teacher: teacher,
                    isManager: isManager,
                    childName: childName(s.childId),
                  ),
                if (sessions.isEmpty)
                  const Text(
                    'No sessions logged yet.',
                    style: TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editRate(BuildContext context, WidgetRef ref) async {
    final fid = ref.read(selectedFamilyIdProvider);
    if (fid == null) return;
    final rate = TextEditingController(
      text: teacher.profile.hourlyRate.toStringAsFixed(0),
    );
    final subjects = TextEditingController(
      text: teacher.profile.subjects.join(', '),
    );
    final name = TextEditingController(text: teacher.profile.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teacher rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(labelText: 'Hourly rate (₹)'),
            ),
            TextField(
              controller: subjects,
              decoration: const InputDecoration(
                labelText: 'Subjects (comma separated)',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final parsed = double.tryParse(rate.text.trim()) ?? 0;
    final nameText = name.text;
    final subjectsText = subjects.text;
    rate.dispose();
    subjects.dispose();
    name.dispose();
    if (ok != true) return;
    await ref.read(tuitionServiceProvider).saveProfile(
          familyId: fid,
          teacherId: teacher.member.uid,
          profile: TeacherProfile(
            userId: teacher.member.uid,
            name: nameText.trim(),
            email: teacher.member.invitedEmail,
            subjects: subjectsText
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
            hourlyRate: parsed,
            assignedChildIds: teacher.member.assignedChildIds,
          ),
        );
  }

  Future<void> _assignChildren(BuildContext context, WidgetRef ref) async {
    final fid = ref.read(selectedFamilyIdProvider);
    if (fid == null) return;
    final kids = ref.read(childrenProvider).valueOrNull ?? [];
    if (kids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add children first (Children tab), then assign.'),
        ),
      );
      return;
    }
    final selected = teacher.member.assignedChildIds.toSet();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Assign children'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in kids)
                CheckboxListTile(
                  value: selected.contains(k.id),
                  onChanged: (v) => setDialog(() {
                    if (v == true) {
                      selected.add(k.id!);
                    } else {
                      selected.remove(k.id);
                    }
                  }),
                  title: Text(k.name),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
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
    if (ok != true) return;
    await ref.read(tuitionServiceProvider).assignChildren(
          familyId: fid,
          teacherId: teacher.member.uid,
          childIds: selected.toList(),
        );
  }

  Future<void> _logSession(    BuildContext context,
    WidgetRef ref,
    List<String> assigned,
    String Function(String) childName,
  ) async {
    final fid = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (fid == null || user == null || assigned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No children assigned to this teacher yet. Assign them when inviting from the Family tab.',
          ),
        ),
      );
      return;
    }
    String childId = assigned.first;
    DateTime day = DateTime.now();
    TimeOfDay startT = const TimeOfDay(hour: 16, minute: 0);
    TimeOfDay endT = const TimeOfDay(hour: 17, minute: 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final start = DateTime(
            day.year, day.month, day.day, startT.hour, startT.minute,
          );
          final end = DateTime(
            day.year, day.month, day.day, endT.hour, endT.minute,
          );
          final hrs = sessionHours(start, end);
          final amt = sessionAmount(hrs, teacher.profile.hourlyRate);
          return AlertDialog(
            title: const Text('Log session'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: childId,
                    decoration: const InputDecoration(labelText: 'Child'),
                    items: [
                      for (final id in assigned)
                        DropdownMenuItem(
                          value: id,
                          child: Text(childName(id)),
                        ),
                    ],
                    onChanged: (v) =>
                        setDialog(() => childId = v ?? assigned.first),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Day ${DateFormat.yMMMd().format(day)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 90),
                            ),
                            lastDate: DateTime.now(),
                            initialDate: day,
                          );
                          if (picked != null) {
                            setDialog(() => day = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Start ${startT.format(context)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startT,
                          );
                          if (picked != null) {
                            setDialog(() => startT = picked);
                          }
                        },
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('End ${endT.format(context)}'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endT,
                          );
                          if (picked != null) {
                            setDialog(() => endT = picked);
                          }
                        },
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    end.isAfter(start)
                        ? '${hrs.toStringAsFixed(2)} hrs × ₹${teacher.profile.hourlyRate.toStringAsFixed(0)} = ₹${amt.toStringAsFixed(0)}'
                        : 'End time must be after start time.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    end.isAfter(start) ? () => Navigator.pop(context, true) : null,
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final start = DateTime(
      day.year, day.month, day.day, startT.hour, startT.minute,
    );
    final end = DateTime(
      day.year, day.month, day.day, endT.hour, endT.minute,
    );
    final hrs = sessionHours(start, end);
    await ref.read(tuitionServiceProvider).logSession(
          familyId: fid,
          teacherId: teacher.member.uid,
          session: TuitionSession(
            childId: childId,
            start: start,
            end: end,
            hours: hrs,
            rateSnapshot: teacher.profile.hourlyRate,
            amount: sessionAmount(hrs, teacher.profile.hourlyRate),
          ),
          loggedBy: user.uid,
        );
  }
}

class _SessionTile extends ConsumerWidget {
  final TuitionSession session;
  final TeacherWithProfile teacher;
  final bool isManager;
  final String childName;
  const _SessionTile({
    required this.session,
    required this.teacher,
    required this.isManager,
    required this.childName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$childName · ${session.hours.toStringAsFixed(2)} hrs · ₹${session.amount.toStringAsFixed(0)}',
      ),
      subtitle: Text(
        '${DateFormat.yMMMd().format(session.start)} · ${session.status}',
      ),
      trailing: isManager
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (session.status == 'logged')
                  TextButton(
                    onPressed: () => _setStatus(ref, 'approved'),
                    child: const Text('Approve'),
                  ),
                if (session.status == 'approved')
                  TextButton(
                    onPressed: () => _setStatus(ref, 'paid'),
                    child: const Text('Mark paid'),
                  ),
                if (session.status == 'paid')
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 20),
              ],
            )
          : _statusChip(),
    );
  }

  Widget _statusChip() {
    final color = session.status == 'paid'
        ? Colors.green
        : session.status == 'approved'
            ? Colors.blue
            : Colors.orange;
    return Chip(
      label: Text(session.status, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.12),
    );
  }

  Future<void> _setStatus(WidgetRef ref, String status) {
    final fid = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (fid == null || user == null) return Future.value();
    return ref.read(tuitionServiceProvider).setStatus(
          familyId: fid,
          teacherId: teacher.member.uid,
          sessionId: session.id!,
          status: status,
          approvedBy: user.uid,
        );
    // The status email is queued by the onSessionStatus Function and sent
    // by the GitHub Action mailer — no client call needed.
  }
}
