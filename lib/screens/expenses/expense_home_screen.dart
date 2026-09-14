import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';

import '../../widgets/app_toast.dart';
import '../../widgets/currency_selector_dialog.dart';
import '../history/monthly_history_screen.dart';
import 'edit_expense_dialog.dart';
import 'preset_management_dialog.dart';
import 'quick_add_popup.dart';
import 'transaction_calendar_dialog.dart';

class ExpenseHomeScreen extends ConsumerStatefulWidget {
  const ExpenseHomeScreen({super.key});

  @override
  ConsumerState<ExpenseHomeScreen> createState() => _ExpenseHomeScreenState();
}

class _ExpenseHomeScreenState extends ConsumerState<ExpenseHomeScreen> {
  String _dateFilter = 'all'; // 'all', 'today', 'yesterday', 'custom'
  DateTime? _selectedCustomDate;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(expenseStatsProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final currency = ref.watch(currencyProvider);


    final usagePct = stats.usagePercentage.clamp(0.0, 100.0);
    Color progressColor = AppTheme.incomeColor; // Green < 80%
    if (stats.usagePercentage >= 100.0) {
      progressColor = AppTheme.expenseColor; // Red >= 100%
    } else if (stats.usagePercentage >= 80.0) {
      progressColor = Colors.amber.shade700; // Amber 80-100%
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Monthly History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MonthlyHistoryScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: const Icon(Icons.currency_exchange, size: 16, color: AppTheme.primaryAccent),
              label: Text(
                '${currency.symbol} (${currency.code})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () => showCurrencySelector(context, ref),
            ),
          ),
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
          // 1. Monthly Summary Card & Dashboard Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Card: Monthly Summary & Budget Target Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MONTHLY SUMMARY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _MetricItem(label: 'Total Income', amount: currency.format(stats.totalIncome), color: AppTheme.incomeColor)),
                            Expanded(child: _MetricItem(label: 'Total Expense', amount: currency.format(stats.totalExpense), color: AppTheme.expenseColor)),
                            Expanded(child: _MetricItem(label: 'Total Savings', amount: currency.format(stats.totalSavings), color: stats.totalSavings >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Target Expense Status Progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Target Expense Status',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                            Text(
                              '${stats.usagePercentage.toStringAsFixed(0)}% of ${currency.format(stats.monthlyTarget)}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: progressColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: usagePct / 100,
                            minHeight: 10,
                            backgroundColor: AppTheme.border,
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Last Month Snapshot Summary Card
                  if (stats.lastMonthExpense > 0 || stats.lastMonthIncome > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('LAST MONTH SNAPSHOT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                              const SizedBox(height: 4),
                              Text('Spent: ${currency.format(stats.lastMonthExpense)} | Saved: ${currency.format(stats.lastMonthIncome - stats.lastMonthExpense)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MonthlyHistoryScreen()),
                              );
                            },
                            child: const Text('View History', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  // Breakdown Matrix
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        _SummaryItem(
                          label: 'Today',
                          amount: currency.format(stats.todayTotal),
                        ),
                        const _VerticalDivider(),
                        _SummaryItem(
                          label: 'This Week',
                          amount: currency.format(stats.weekTotal),
                        ),
                        const _VerticalDivider(),
                        _SummaryItem(
                          label: 'This Month',
                          amount: currency.format(stats.monthTotal),
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: stats.categoryBreakdown.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
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
                                    currency.format(entry.value),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],


                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'RECENT TRANSACTIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await TransactionCalendarDialog.show(
                            context,
                            initialDate: _selectedCustomDate ?? DateTime.now(),
                            expenses: expensesAsync.value ?? [],
                            currencySymbol: currency.symbol,
                          );
                          if (picked != null) {
                            setState(() {
                              _dateFilter = 'custom';
                              _selectedCustomDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.calendar_month, size: 14, color: AppTheme.primaryAccent),
                              SizedBox(width: 3),
                              Text(
                                'Calendar',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_dateFilter != 'all')
                        InkWell(
                          onTap: () => setState(() {
                            _dateFilter = 'all';
                            _selectedCustomDate = null;
                          }),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.close, size: 14, color: AppTheme.textSecondary),
                                SizedBox(width: 2),
                                Text(
                                  'Clear Filter',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Date Filter Selection Strip
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDateFilterChip('all', 'All'),
                        const SizedBox(width: 8),
                        _buildDateFilterChip('today', 'Today'),
                        const SizedBox(width: 8),
                        _buildDateFilterChip('yesterday', 'Yesterday'),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: Icon(
                            Icons.calendar_today,
                            size: 13,
                            color: _dateFilter == 'custom' ? Colors.white : AppTheme.primaryAccent,
                          ),
                          label: Text(
                            _selectedCustomDate != null && _dateFilter == 'custom'
                                ? DateFormat('d MMM').format(_selectedCustomDate!)
                                : 'Pick Date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _dateFilter == 'custom' ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          backgroundColor: _dateFilter == 'custom' ? AppTheme.primaryAccent : AppTheme.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: _dateFilter == 'custom' ? AppTheme.primaryAccent : AppTheme.border,
                            ),
                          ),
                          onPressed: () async {
                            final picked = await TransactionCalendarDialog.show(
                              context,
                              initialDate: _selectedCustomDate ?? DateTime.now(),
                              expenses: expensesAsync.value ?? [],
                              currencySymbol: currency.symbol,
                            );
                            if (picked != null) {
                              setState(() {
                                _dateFilter = 'custom';
                                _selectedCustomDate = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Chronological History List Grouped by Date (Filtered)
          expensesAsync.when(
            data: (expenses) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final yesterday = today.subtract(const Duration(days: 1));

              List<Expense> filteredExpenses;
              String emptyTitle;
              if (_dateFilter == 'today') {
                filteredExpenses = expenses.where((e) {
                  final d = DateTime(e.date.year, e.date.month, e.date.day);
                  return d.isAtSameMomentAs(today);
                }).toList();
                emptyTitle = 'No Transactions Recorded for Today';
              } else if (_dateFilter == 'yesterday') {
                filteredExpenses = expenses.where((e) {
                  final d = DateTime(e.date.year, e.date.month, e.date.day);
                  return d.isAtSameMomentAs(yesterday);
                }).toList();
                emptyTitle = 'No Transactions Recorded for Yesterday';
              } else if (_dateFilter == 'custom' && _selectedCustomDate != null) {
                final target = DateTime(
                    _selectedCustomDate!.year, _selectedCustomDate!.month, _selectedCustomDate!.day);
                filteredExpenses = expenses.where((e) {
                  final d = DateTime(e.date.year, e.date.month, e.date.day);
                  return d.isAtSameMomentAs(target);
                }).toList();
                emptyTitle = 'No Transactions on ${DateFormat('d MMM yyyy').format(_selectedCustomDate!)}';
              } else {
                filteredExpenses = expenses;
                emptyTitle = 'No Expenses Logged Yet';
              }

              if (filteredExpenses.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet_outlined,
                              size: 44, color: AppTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            emptyTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dateFilter == 'all'
                                ? 'Tap "+" to quickly add daily expenses or income.'
                                : 'Tap "All" above to see all transactions for this month.',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final groupedMap = _groupExpensesByDate(filteredExpenses);

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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(dayExpenses.length, (itemIdx) {
                                final expense = dayExpenses[itemIdx];
                                final isExpense = expense.type == 'expense';

                                return Column(
                                  children: [
                                    if (itemIdx > 0) const Divider(height: 1, color: AppTheme.border),
                                    Dismissible(
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
                                      child: Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          onTap: () => EditExpenseDialog.show(context, expense),
                                          onLongPress: () {
                                            _deleteExpenseWithUndo(context, ref, expense);
                                          },
                                          title: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  expense.name,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: AppTheme.textPrimary,
                                                  ),
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
                                            '${isExpense ? "-" : "+"}${currency.format(expense.amount)}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isExpense
                                                  ? AppTheme.textPrimary
                                                  : AppTheme.incomeColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
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
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('Error: $err')),
              ),
            ),

          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expense_home_fab',
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
      AppToast.showUndo(
        context: context,
        message: 'Deleted "${expense.name}"',
        onUndo: () async {
          await repo.addExpense(
            name: expense.name,
            category: expense.category,
            amount: expense.amount,
            type: expense.type,
            date: expense.date,
          );
        },
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

  Widget _buildDateFilterChip(String filterKey, String label) {
    final isSelected = _dateFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryAccent,
      backgroundColor: AppTheme.cardBg,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryAccent : AppTheme.border,
        ),
      ),
      onSelected: (_) {
        setState(() {
          _dateFilter = filterKey;
          _selectedCustomDate = null;
        });
      },
    );
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
        mainAxisSize: MainAxisSize.min,
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

class _MetricItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

