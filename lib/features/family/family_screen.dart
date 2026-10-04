import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/rbac/roles.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/children/children_providers.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/features/family/family_service.dart';

/// Family workspace: create/select family, view members + roles, invite by
/// email. Only owner/parent can invite.
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _familyName = TextEditingController();
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _familyName.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    final user = ref.read(currentUserProvider);
    final name = _familyName.text.trim();
    if (user == null || name.isEmpty) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final id = await ref
          .read(familyServiceProvider)
          .createFamily(name: name, uid: user.uid);
      ref.read(selectedFamilyIdProvider.notifier).state = id;
      _familyName.clear();
      setState(() => _notice = 'Family "$name" created.');
    } on FamilyException catch (e) {
      setState(() => _notice = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final fid = ref.read(selectedFamilyIdProvider);
    if (fid == null) return;
    final emailCtrl = TextEditingController();
    FamilyRole role = FamilyRole.child;
    final assigned = <String>{};
    final kids = ref.read(childrenProvider).valueOrNull ?? [];
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Invite member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'member@example.com',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FamilyRole>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: FamilyRole.parent,
                      child: Text('Parent — full access'),
                    ),
                    DropdownMenuItem(
                      value: FamilyRole.child,
                      child: Text('Child — own data only'),
                    ),
                    DropdownMenuItem(
                      value: FamilyRole.teacher,
                      child: Text('Teacher — assigned children'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDialog(() => role = v ?? FamilyRole.child),
                ),
                if (role == FamilyRole.teacher && kids.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Assign children',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final k in kids)
                        FilterChip(
                          label: Text(k.name),
                          selected: assigned.contains(k.id),
                          onSelected: (sel) => setDialog(() {
                            if (sel) {
                              assigned.add(k.id!);
                            } else {
                              assigned.remove(k.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Existing GRP accounts join instantly. New emails get a pending invite.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                {
                  'email': emailCtrl.text.trim(),
                  'role': role,
                  'assigned': assigned.toList(),
                },
              ),
              child: const Text('Send invite'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
    if (result == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final msg = await ref.read(familyServiceProvider).inviteByEmail(
            familyId: fid,
            email: result['email'] as String,
            role: result['role'] as FamilyRole,
            assignedChildIds:
                (result['assigned'] as List).map((e) => e as String).toList(),
          );
      setState(() => _notice = msg);
    } on FamilyException catch (e) {
      setState(() => _notice = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiesAsync = ref.watch(familiesProvider);
    final membersAsync = ref.watch(membersProvider);
    final invitesAsync = ref.watch(invitesProvider);
    final selectedId = ref.watch(selectedFamilyIdProvider);
    final myRole = ref.watch(myRoleProvider);
    final canInvite = myRole == null || myRole.isManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        actions: [
          if (selectedId != null && canInvite)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite member',
              onPressed: _busy ? null : _invite,
            ),
        ],
      ),
      body: familiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load families: $e')),
        data: (families) {
          // Auto-select the first family once.
          if (selectedId == null && families.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedFamilyIdProvider.notifier).state =
                  families.first.id;
            });
          }
          if (families.isEmpty) return _emptyState();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: selectedId != null &&
                        families.any((f) => f.id == selectedId)
                    ? selectedId
                    : null,
                decoration: const InputDecoration(labelText: 'Family'),
                items: [
                  for (final f in families)
                    DropdownMenuItem(value: f.id, child: Text(f.name)),
                ],
                onChanged: (v) =>
                    ref.read(selectedFamilyIdProvider.notifier).state = v,
              ),
              const SizedBox(height: 8),
              _createFamilyRow(),
              if (_notice != null) ...[
                const SizedBox(height: 8),
                Text(_notice!, style: const TextStyle(color: Colors.black87)),
              ],
              const SizedBox(height: 16),
              Text(
                'Members (${membersAsync.valueOrNull?.length ?? 0})'
                '${myRole != null ? ' · you are ${myRole.name}' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const _Loading(),
                error: (e, _) => Text('Could not load members: $e'),
                data: (members) => Column(
                  children: [
                    for (final m in members)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (m.invitedEmail.isNotEmpty
                                      ? m.invitedEmail
                                      : m.uid)
                                  .substring(0, 1)
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(
                            m.invitedEmail.isEmpty ? m.uid : m.invitedEmail,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${m.role.name}${m.status != 'active' ? ' · ${m.status}' : ''}',
                          ),
                          trailing: m.role.isManager
                              ? const Icon(Icons.star, size: 18)
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pending invites (${invitesAsync.valueOrNull?.length ?? 0})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              invitesAsync.when(
                loading: () => const _Loading(),
                error: (e, _) => Text('Could not load invites: $e'),
                data: (invites) => Column(
                  children: [
                    for (final i in invites)
                      ListTile(
                        leading: const Icon(Icons.mail_outline),
                        title: Text(i.email),
                        subtitle: Text(i.role),
                      ),
                    if (invites.isEmpty)
                      const Text(
                        'No pending invites.',
                        style: TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Create your family workspace',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Families share todos, finance, children and chat. Invite members by email afterwards.',
        ),
        const SizedBox(height: 16),
        _createFamilyRow(),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(_notice!),
        ],
      ],
    );
  }

  Widget _createFamilyRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _familyName,
            decoration: const InputDecoration(
              labelText: 'New family name',
              hintText: 'e.g. The Kumars',
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _busy ? null : _createFamily,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
