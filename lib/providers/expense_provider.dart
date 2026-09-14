import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/expense_repository.dart';
import 'profile_provider.dart';


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

final currentMonthExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final now = DateTime.now();
  return ref.watch(expenseRepositoryProvider).watchExpensesForMonth(now);
});

final presetsStreamProvider = StreamProvider<List<Preset>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAllPresets();
});

final presetsByTypeStreamProvider = StreamProvider.family<List<Preset>, String>((ref, type) {
  return ref.watch(expenseRepositoryProvider).watchPresetsByType(type);
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
  final double totalSavings;
  final double monthlyTarget;
  final double dailyTarget;
  final double usagePercentage;
  final Expense? pinnedSalary;
  final Map<String, double> categoryBreakdown;
  final double lastMonthExpense;
  final double lastMonthIncome;

  const ExpenseStats({
    required this.todayTotal,
    required this.todayIncome,
    required this.weekTotal,
    required this.monthTotal,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.totalSavings,
    required this.monthlyTarget,
    required this.dailyTarget,
    required this.usagePercentage,
    this.pinnedSalary,
    required this.categoryBreakdown,
    required this.lastMonthExpense,
    required this.lastMonthIncome,
  });
}

final expenseStatsProvider = Provider<ExpenseStats>((ref) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final profile = ref.watch(profileNotifierProvider);
  final expenses = expensesAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  // Find start of current week (Monday)
  final weekday = now.weekday; // 1 = Monday, 7 = Sunday
  final startOfWeek = DateTime(now.year, now.month, now.day - (weekday - 1));

  // Find start of current month
  final startOfMonth = DateTime(now.year, now.month, 1);


  // Find range for last month
  final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
  final endOfLastMonth = DateTime(now.year, now.month, 1).subtract(const Duration(milliseconds: 1));

  double todayTotal = 0.0;
  double todayIncome = 0.0;
  double weekTotal = 0.0;
  double monthTotal = 0.0;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double lastMonthExpense = 0.0;
  double lastMonthIncome = 0.0;
  Expense? pinnedSalary;

  final Map<String, double> categoryBreakdown = {};

  for (final entry in expenses) {
    final isExpense = entry.type == 'expense';
    final amount = entry.amount;
    final date = entry.date;

    // Last Month calculations
    if (date.isAfter(startOfLastMonth.subtract(const Duration(milliseconds: 1))) &&
        date.isBefore(endOfLastMonth.add(const Duration(milliseconds: 1)))) {
      if (isExpense) {
        lastMonthExpense += amount;
      } else {
        lastMonthIncome += amount;
      }
      continue; // Focus current statistics on current month/active timeline
    }

    // Current Month calculations
    if (date.isBefore(startOfMonth)) continue;

    if (isExpense) {
      totalExpense += amount;
      monthTotal += amount;

      // Category breakdown (for expenses)
      categoryBreakdown[entry.category] = (categoryBreakdown[entry.category] ?? 0.0) + amount;

      if (date.isAfter(startOfToday.subtract(const Duration(milliseconds: 1))) &&
          date.isBefore(endOfToday.add(const Duration(milliseconds: 1)))) {
        todayTotal += amount;
      }

      if (date.isAfter(startOfWeek.subtract(const Duration(milliseconds: 1)))) {
        weekTotal += amount;
      }
    } else {
      // Income entry
      if ((entry.name == 'Monthly Salary' || entry.name == 'Salary') && pinnedSalary == null) {
        pinnedSalary = entry;
      }

      totalIncome += amount;

      if (date.isAfter(startOfToday.subtract(const Duration(milliseconds: 1))) &&
          date.isBefore(endOfToday.add(const Duration(milliseconds: 1)))) {
        todayIncome += amount;
      }
    }
  }

  final monthlyTarget = profile.monthlyExpenseTarget > 0 ? profile.monthlyExpenseTarget : 15000.0;
  final dailyTarget = profile.dailyExpenseTarget > 0 ? profile.dailyExpenseTarget : 500.0;
  final usagePercentage = (totalExpense / monthlyTarget) * 100;
  final netBalance = totalIncome - totalExpense;

  return ExpenseStats(
    todayTotal: todayTotal,
    todayIncome: todayIncome,
    weekTotal: weekTotal,
    monthTotal: monthTotal,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    netBalance: netBalance,
    totalSavings: netBalance,
    monthlyTarget: monthlyTarget,
    dailyTarget: dailyTarget,
    usagePercentage: usagePercentage,
    pinnedSalary: pinnedSalary,
    categoryBreakdown: categoryBreakdown,
    lastMonthExpense: lastMonthExpense,
    lastMonthIncome: lastMonthIncome,
  );
});

