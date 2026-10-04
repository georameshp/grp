import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/storage/r2_storage_service.dart';
import 'package:grp/features/auth/auth_providers.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/features/finance/finance_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Income / expense / loan / repayment / investment ledger with a monthly
/// summary header. Only owner/parent can add (matches Firestore rules).
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fid = ref.watch(selectedFamilyIdProvider);
    final txAsync = ref.watch(transactionsProvider);
    final filtered = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(financeTypeFilterProvider);
    final myRole = ref.watch(myRoleProvider);
    final canEdit = myRole == null || myRole.isManager;
    final now = DateTime.now();
    final summary = summarizeMonth(txAsync.valueOrNull ?? [], now);

    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      floatingActionButton: fid == null || !canEdit
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
                'Create or select a family first (Family tab) to track money.',
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMM().format(now),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _amount('In', summary.income, Colors.green),
                          _amount('Out', summary.expense, Colors.red),
                          _amount(
                            'Balance',
                            summary.balance,
                            summary.balance >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _chip(ref, 'all', 'All', filter),
                  for (final t in financeTypes) _chip(ref, t, t, filter),
                ],
              ),
            ),
          ],
          Expanded(
            child: txAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load finance: $e')),
              data: (_) {
                if (fid == null) return const SizedBox.shrink();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No entries. Tap + to add one.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final t = filtered[i];
                    final out = expenseLike.contains(t.type);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              (out ? Colors.red : Colors.green).withOpacity(0.12),
                          child: Icon(
                            out ? Icons.arrow_upward : Icons.arrow_downward,
                            color: out ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(
                          '${t.category} · ${t.type.replaceAll('_', ' ')}',
                        ),
                        subtitle: Text(
                          '${DateFormat.yMMMd().format(t.date)}'
                          '${t.notes.isNotEmpty ? ' · ${t.notes}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${out ? '-' : '+'}${t.amount.toStringAsFixed(0)} ${t.currency}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: out ? Colors.red : Colors.green,
                              ),
                            ),
                            if (t.receiptUrl.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.receipt_outlined,
                                    size: 20),
                                tooltip: 'View receipt',
                                onPressed: () =>
                                    _openReceipt(context, t.receiptUrl),
                              ),
                            if (canEdit)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => ref
                                    .read(financeServiceProvider)
                                    .remove(fid, t.id!),
                              ),
                          ],
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

  Widget _amount(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(
          value.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _chip(WidgetRef ref, String value, String label, String current) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: current == value,
        onSelected: (_) =>
            ref.read(financeTypeFilterProvider.notifier).state = value,
      ),
    );
  }

  Future<void> _showAdd(BuildContext context, WidgetRef ref) async {
    final fid = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (fid == null || user == null) return;
    final amount = TextEditingController();
    final category = TextEditingController();
    final notes = TextEditingController();
    String type = 'expense';
    DateTime date = DateTime.now();
    String? receiptUrl;
    bool uploading = false;
    String? uploadError;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('New entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in financeTypes)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setDialog(() => type = v ?? 'expense'),
                ),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: 'Category (food, rent, salary…)',
                  ),
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
                        receiptUrl == null
                            ? 'No receipt attached'
                            : 'Receipt attached ✓',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: uploading
                          ? null
                          : () => _pickReceipt(
                                context, ref, fid, setDialog,
                                (url) => receiptUrl = url,
                                (v) => uploading = v,
                                (e) => uploadError = e,
                              ),
                      icon: uploading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.attach_file, size: 18),
                      label: Text(
                        receiptUrl == null ? 'Attach' : 'Replace',
                      ),
                    ),
                    if (receiptUrl != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Remove receipt',
                        onPressed: uploading
                            ? null
                            : () => setDialog(() => receiptUrl = null),
                      ),
                  ],
                ),
                if (uploadError != null)
                  Text(
                    uploadError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date ${DateFormat.yMMMd().format(date)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDate: date,
                        );
                        if (picked != null) setDialog(() => date = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ],
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final parsed = double.tryParse(amount.text.trim());
    final cat = category.text;
    final note = notes.text;
    amount.dispose();
    category.dispose();
    notes.dispose();
    if (ok != true || parsed == null || parsed <= 0) return;
    await ref.read(financeServiceProvider).add(
          familyId: fid,
          createdBy: user.uid,
          type: type,
          amount: parsed,
          category: cat,
          date: date,
          notes: note,
          receiptUrl: receiptUrl ?? '',
        );
  }

  /// Picks a receipt photo, uploads it to R2 and reports back via callbacks
  /// (the dialog owns its [setDialog] state).
  Future<void> _pickReceipt(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    void Function(VoidCallback) setDialog,
    void Function(String) onUploaded,
    void Function(bool) onUploading,
    void Function(String?) onError,
  ) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setDialog(() {
        onUploading(true);
        onError(null);
      });
      final url = await R2StorageService().upload(
        familyId: familyId,
        kind: 'receipts',
        filename: picked.name,
        bytes: bytes,
      );
      setDialog(() {
        onUploading(false);
        onUploaded(url);
      });
    } on R2UploadException catch (e) {
      setDialog(() {
        onUploading(false);
        onError(e.message);
      });
    } catch (_) {
      setDialog(() {
        onUploading(false);
        onError('Could not attach receipt.');
      });
    }
  }

  Future<void> _openReceipt(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open receipt.')),
        );
      }
    }
  }
}
