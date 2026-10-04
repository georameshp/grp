import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grp/core/rbac/roles.dart';
import 'package:grp/features/dashboard/dashboard_screen.dart';
import 'package:grp/features/finance/finance_providers.dart';
import 'package:grp/models/grp_models.dart';
import 'package:grp/models/tuition_models.dart';

void main() {
  group('Phase 1 — GRP MVP', () {
    test('family roles parse and gate correctly', () {
      expect(familyRoleFromString('owner'), FamilyRole.owner);
      expect(familyRoleFromString('parent').isManager, isTrue);
      expect(familyRoleFromString('teacher').isTeacher, isTrue);
      expect(familyRoleFromString('teacher').isManager, isFalse);
      expect(familyRoleFromString('nope'), FamilyRole.child);
    });

    test('month summary splits income-like vs expense-like', () {
      final txs = [
        TransactionEntry(
          type: 'income',
          amount: 100,
          date: DateTime(2026, 9, 5),
        ),
        TransactionEntry(
          type: 'expense',
          amount: 40,
          date: DateTime(2026, 9, 6),
        ),
        TransactionEntry(
          type: 'expense',
          amount: 999,
          date: DateTime(2026, 8, 6),
        ),
      ];
      final sept = summarizeMonth(txs, DateTime(2026, 9, 15));
      expect(sept.income, 100);
      expect(sept.expense, 40);
      expect(sept.balance, 60);
    });

    testWidgets('dashboard renders empty state without family', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Dashboard'), findsOneWidget);
    });

    test('session hours and amount math', () {
      final start = DateTime(2026, 9, 1, 16, 0);
      final end = DateTime(2026, 9, 1, 17, 30);
      expect(sessionHours(start, end), 1.5);
      expect(sessionAmount(1.5, 500), 750);
    });

    test('payment due sums approved sessions only', () {
      final now = DateTime(2026, 9, 1, 16);
      final sessions = [
        TuitionSession(
          childId: 'c1',
          start: now,
          end: now.add(const Duration(hours: 1)),
          amount: 500,
          status: 'approved',
        ),
        TuitionSession(
          childId: 'c1',
          start: now,
          end: now.add(const Duration(hours: 1)),
          amount: 500,
          status: 'logged',
        ),
        TuitionSession(
          childId: 'c1',
          start: now,
          end: now.add(const Duration(hours: 1)),
          amount: 500,
          status: 'paid',
        ),
      ];
      expect(paymentDue(sessions), 500);
    });
  });
}
