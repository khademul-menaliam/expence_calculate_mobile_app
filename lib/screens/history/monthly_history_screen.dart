import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';

class MonthlyHistoryScreen extends ConsumerWidget {
  const MonthlyHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final currency = ref.watch(currencyProvider);

    final expenses = expensesAsync.valueOrNull ?? [];

    // Group expenses by Year-Month key
    final Map<String, List<Expense>> monthlyGroups = {};
    for (final exp in expenses) {
      final key = DateFormat('yyyy-MM').format(exp.date);
      monthlyGroups.putIfAbsent(key, () => []).add(exp);
    }

    final sortedKeys = monthlyGroups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly History'),
      ),
      body: sortedKeys.isEmpty
          ? const Center(child: Text('No historical data available.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final key = sortedKeys[index];
                final monthExpenses = monthlyGroups[key]!;
                final monthDate = DateTime.parse('$key-01');
                final monthName = DateFormat('MMMM yyyy').format(monthDate);

                double totalIncome = 0.0;
                double totalExpense = 0.0;

                for (final item in monthExpenses) {
                  if (item.type == 'expense') {
                    totalExpense += item.amount;
                  } else if (item.isPaid) {
                    totalIncome += item.amount;
                  }
                }

                final netSavings = totalIncome - totalExpense;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      monthName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Spent: ${currency.format(totalExpense)} | Saved: ${currency.format(netSavings)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: netSavings >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor,
                        ),
                      ),
                    ),
                    children: [
                      const Divider(height: 1),
                      Column(
                        children: monthExpenses.map((item) {
                          final isExpense = item.type == 'expense';
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text('${item.category} • ${DateFormat('d MMM').format(item.date)}'),
                            trailing: Text(
                              '${isExpense ? '-' : '+'}${currency.format(item.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                  ),
                );
              },
            ),
    );
  }
}
