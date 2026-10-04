import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grp/core/firebase/firebase_bootstrap.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/models/grp_models.dart';

/// Transaction types supported in the MVP.
const financeTypes = [
  'income',
  'expense',
  'loan_given',
  'loan_taken',
  'repayment',
  'investment',
];

const incomeLike = {'income', 'loan_taken'};
const expenseLike = {'expense', 'loan_given', 'repayment', 'investment'};

class FinanceService {
  final FirebaseFirestore _db;
  FinanceService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String familyId) => _db
      .collection(Family.collection)
      .doc(familyId)
      .collection(TransactionEntry.sub);

  bool get _ready => FirebaseBootstrap.isReady;

  Stream<List<TransactionEntry>> transactions(String familyId) {
    if (!_ready) return Stream.value(const []);
    return _col(familyId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TransactionEntry.fromDoc).toList());
  }

  Future<void> add({
    required String familyId,
    required String createdBy,
    required String type,
    required double amount,
    String category = 'general',
    DateTime? date,
    String notes = '',
    String currency = 'INR',
    String receiptUrl = '',
  }) async {
    await _col(familyId).add(TransactionEntry(
      type: type,
      amount: amount,
      currency: currency,
      category: category.trim().isEmpty ? 'general' : category.trim(),
      date: date ?? DateTime.now(),
      notes: notes.trim(),
      receiptUrl: receiptUrl,
    ).toJson(createdBy));
  }

  Future<void> remove(String familyId, String id) =>
      _col(familyId).doc(id).delete();
}

final financeServiceProvider =
    Provider<FinanceService>((ref) => FinanceService());

final transactionsProvider = StreamProvider<List<TransactionEntry>>((ref) {
  final fid = ref.watch(selectedFamilyIdProvider);
  if (fid == null) return Stream.value(const <TransactionEntry>[]);
  return ref.watch(financeServiceProvider).transactions(fid);
});

final financeTypeFilterProvider = StateProvider<String>((ref) => 'all');

final filteredTransactionsProvider =
    Provider<List<TransactionEntry>>((ref) {
  final filter = ref.watch(financeTypeFilterProvider);
  final all = ref.watch(transactionsProvider).valueOrNull ?? [];
  if (filter == 'all') return all;
  return all.where((t) => t.type == filter).toList();
});

/// Sums for a given month (income-like vs expense-like).
class MonthSummary {
  final double income;
  final double expense;
  const MonthSummary({this.income = 0, this.expense = 0});
  double get balance => income - expense;
}

MonthSummary summarizeMonth(List<TransactionEntry> all, DateTime month) {
  double income = 0, expense = 0;
  for (final t in all) {
    if (t.date.year != month.year || t.date.month != month.month) continue;
    if (incomeLike.contains(t.type)) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }
  return MonthSummary(income: income, expense: expense);
}
