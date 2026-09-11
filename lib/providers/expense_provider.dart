import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/expense_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseProvider));
});

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAllExpenses();
});

final presetsStreamProvider = StreamProvider<List<Preset>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAllPresets();
});

// Helper class for computed statistics
class ExpenseStats {
  final double todayTotal;
  final double todayIncome;
  final double weekTotal;
  final double monthTotal;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final Map<String, double> categoryBreakdown; // Category -> total expense amount

  const ExpenseStats({
    required this.todayTotal,
    required this.todayIncome,
    required this.weekTotal,
    required this.monthTotal,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.categoryBreakdown,
  });
}

final expenseStatsProvider = Provider<ExpenseStats>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final expenses = expensesAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  // Find start of current week (Monday)
  final weekday = now.weekday; // 1 = Monday, 7 = Sunday
  final startOfWeek = DateTime(now.year, now.month, now.day - (weekday - 1));

  // Find start of current month
  final startOfMonth = DateTime(now.year, now.month, 1);

  double todayTotal = 0.0;
  double todayIncome = 0.0;
  double weekTotal = 0.0;
  double monthTotal = 0.0;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  final Map<String, double> categoryBreakdown = {};

  for (final entry in expenses) {
    final isExpense = entry.type == 'expense';
    final amount = entry.amount;
    final date = entry.date;

    if (isExpense) {
      totalExpense += amount;

      // Category breakdown (for expenses)
      categoryBreakdown[entry.category] = (categoryBreakdown[entry.category] ?? 0.0) + amount;

      if (date.isAfter(startOfToday.subtract(const Duration(milliseconds: 1))) &&
          date.isBefore(endOfToday.add(const Duration(milliseconds: 1)))) {
        todayTotal += amount;
      }

      if (date.isAfter(startOfWeek.subtract(const Duration(milliseconds: 1)))) {
        weekTotal += amount;
      }

      if (date.isAfter(startOfMonth.subtract(const Duration(milliseconds: 1)))) {
        monthTotal += amount;
      }
    } else {
      totalIncome += amount;

      if (date.isAfter(startOfToday.subtract(const Duration(milliseconds: 1))) &&
          date.isBefore(endOfToday.add(const Duration(milliseconds: 1)))) {
        todayIncome += amount;
      }
    }
  }

  return ExpenseStats(
    todayTotal: todayTotal,
    todayIncome: todayIncome,
    weekTotal: weekTotal,
    monthTotal: monthTotal,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    netBalance: totalIncome - totalExpense,
    categoryBreakdown: categoryBreakdown,
  );
});
