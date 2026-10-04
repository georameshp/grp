import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grp/features/family/family_providers.dart';
import 'package:grp/features/finance/finance_providers.dart';
import 'package:grp/features/todos/todos_providers.dart';
import 'package:grp/models/grp_models.dart';
import 'package:intl/intl.dart';

const _palette = [
  Colors.blue,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.brown,
  Colors.cyan,
];

/// MVP dashboard: summary cards + income-vs-expense bars + expense-by-category
/// pie, all computed from the selected family's live streams.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fid = ref.watch(selectedFamilyIdProvider);
    final todos = ref.watch(todosProvider).valueOrNull ?? [];
    final txs = ref.watch(transactionsProvider).valueOrNull ?? [];
    final loading = ref.watch(todosProvider).isLoading ||
        ref.watch(transactionsProvider).isLoading;

    final now = DateTime.now();
    final month = summarizeMonth(txs, now);
    final openTasks = todos.where((t) => !t.done).length;
    final buckets = _lastMonths(txs, now, 6);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : fid == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Create or select a family (Family tab) to see your dashboard.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _card(context, 'Open tasks', '$openTasks',
                            Colors.blue),
                        _card(
                          context,
                          '${DateFormat.MMM().format(now)} income',
                          month.income.toStringAsFixed(0),
                          Colors.green,
                        ),
                        _card(
                          context,
                          '${DateFormat.MMM().format(now)} spent',
                          month.expense.toStringAsFixed(0),
                          Colors.red,
                        ),
                        _card(
                          context,
                          'Balance',
                          month.balance.toStringAsFixed(0),
                          month.balance >= 0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Manage',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _navTile(context, Icons.child_care_outlined,
                            'Children', '/children'),
                        _navTile(context, Icons.school_outlined,
                            'Tuition', '/tuition'),
                        _navTile(context, Icons.group_outlined,
                            'Family', '/family'),
                        _navTile(context, Icons.person_outlined,
                            'Profile', '/profile'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Income vs expense (6 months)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                          child: _bars(buckets),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Spending by category (this month)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _pie(txs, now),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _card(
      BuildContext context, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(
      BuildContext context, IconData icon, String label, String route) {
    return InkWell(
      onTap: () => context.push(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            child: Icon(icon),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// Last [count] months oldest→newest with income/expense sums.
  List<_Bucket> _lastMonths(
      List<TransactionEntry> all, DateTime now, int count) {
    final out = <_Bucket>[];
    for (int i = count - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final s = summarizeMonth(all, m);
      out.add(_Bucket(DateFormat.MMM().format(m), s.income, s.expense));
    }
    return out;
  }

  Widget _bars(List<_Bucket> buckets) {
    final maxVal = buckets.fold<double>(
      100,
      (m, b) => [m, b.income, b.expense].reduce((a, c) => a > c ? a : c),
    );
    return BarChart(
      BarChartData(
        maxY: maxVal * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    buckets[i].label,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].income,
                  color: Colors.green,
                  width: 10,
                  borderRadius: BorderRadius.zero,
                ),
                BarChartRodData(
                  toY: buckets[i].expense,
                  color: Colors.red,
                  width: 10,
                  borderRadius: BorderRadius.zero,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _pie(List<TransactionEntry> all, DateTime month) {
    final byCat = <String, double>{};
    for (final t in all) {
      if (!expenseLike.contains(t.type)) continue;
      if (t.date.year != month.year || t.date.month != month.month) continue;
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    if (byCat.isEmpty) {
      return const Center(child: Text('No spending this month yet.'));
    }
    final entries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 28,
              sectionsSpace: 2,
              sections: [
                for (int i = 0; i < entries.length && i < 7; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: _palette[i % _palette.length],
                    title:
                        '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                    radius: 56,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < entries.length && i < 7; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: _palette[i % _palette.length],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${entries[i].key} (${entries[i].value.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bucket {
  final String label;
  final double income;
  final double expense;
  const _Bucket(this.label, this.income, this.expense);
}
