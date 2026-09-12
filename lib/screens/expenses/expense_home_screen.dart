import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';
import 'edit_expense_dialog.dart';
import 'preset_management_dialog.dart';
import 'quick_add_popup.dart';

class ExpenseHomeScreen extends ConsumerWidget {
  const ExpenseHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(expenseStatsProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: 'Manage Presets',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PresetManagementScreen()),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Summary Cards Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Totals Summary Matrix
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        // Net Balance Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'NET BALANCE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              currencyFormat.format(stats.netBalance),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: stats.netBalance >= 0
                                    ? AppTheme.incomeColor
                                    : AppTheme.expenseColor,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: AppTheme.border),
                        ),
                        // Today / Week / Month Grid
                        Row(
                          children: [
                            _SummaryItem(
                              label: 'Today',
                              amount: currencyFormat.format(stats.todayTotal),
                            ),
                            const _VerticalDivider(),
                            _SummaryItem(
                              label: 'This Week',
                              amount: currencyFormat.format(stats.weekTotal),
                            ),
                            const _VerticalDivider(),
                            _SummaryItem(
                              label: 'This Month',
                              amount: currencyFormat.format(stats.monthTotal),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Category-wise Breakdown Section
                  if (stats.categoryBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'CATEGORY BREAKDOWN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stats.categoryBreakdown.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final entry = stats.categoryBreakdown.entries.elementAt(index);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  currencyFormat.format(entry.value),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text(
                    'RECENT TRANSACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Chronological History List Grouped by Date
          expensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 48, color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text(
                            'No Expenses Logged Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap "+" to quickly add daily expenses or income.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final groupedMap = _groupExpensesByDate(expenses);

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dateHeader = groupedMap.keys.elementAt(index);
                      final dayExpenses = groupedMap[dateHeader]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Text(
                              dateHeader,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                          ),
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: dayExpenses.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: AppTheme.border),
                              itemBuilder: (context, itemIdx) {
                                final expense = dayExpenses[itemIdx];
                                final isExpense = expense.type == 'expense';

                                return Dismissible(
                                  key: Key('expense_${expense.id}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: AppTheme.expenseColor,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                        SizedBox(width: 4),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onDismissed: (_) {
                                    _deleteExpenseWithUndo(context, ref, expense);
                                  },
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    onTap: () => EditExpenseDialog.show(context, expense),
                                    onLongPress: () {
                                      _deleteExpenseWithUndo(context, ref, expense);
                                    },
                                    title: Row(
                                      children: [
                                        Text(
                                          expense.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: const Color(0xFFCBD5E1), width: 0.8),
                                          ),
                                          child: Text(
                                            expense.category,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      DateFormat.jm().format(expense.date),
                                      style: const TextStyle(
                                          fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    trailing: Text(
                                      '${isExpense ? "-" : "+"}${currencyFormat.format(expense.amount)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isExpense
                                            ? AppTheme.textPrimary
                                            : AppTheme.incomeColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                    childCount: groupedMap.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => QuickAddPopup.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Quick Add'),
      ),
    );
  }

  Future<void> _deleteExpenseWithUndo(
      BuildContext context, WidgetRef ref, Expense expense) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.deleteExpense(expense.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${expense.name}"'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amber,
            onPressed: () async {
              await repo.addExpense(
                name: expense.name,
                category: expense.category,
                amount: expense.amount,
                type: expense.type,
                date: expense.date,
              );
            },
          ),
        ),
      );
    }
  }

  Map<String, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final Map<String, List<Expense>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final expense in expenses) {
      final dateOnly = DateTime(expense.date.year, expense.date.month, expense.date.day);
      String label;

      if (dateOnly.isAtSameMomentAs(today)) {
        label = 'Today';
      } else if (dateOnly.isAtSameMomentAs(yesterday)) {
        label = 'Yesterday';
      } else {
        label = DateFormat('EEEE, MMM d, yyyy').format(expense.date);
      }

      grouped.putIfAbsent(label, () => []).add(expense);
    }
    return grouped;
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String amount;

  const _SummaryItem({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: AppTheme.border,
    );
  }
}
