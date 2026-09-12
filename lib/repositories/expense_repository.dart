import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ExpenseRepository {
  final AppDatabase db;

  ExpenseRepository(this.db);

  // --- Expenses ---

  Stream<List<Expense>> watchAllExpenses() {
    return (db.select(db.expenses)
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Stream<List<Expense>> watchExpensesForMonth(DateTime monthDate) {
    final start = DateTime(monthDate.year, monthDate.month, 1);
    final end = DateTime(monthDate.year, monthDate.month + 1, 1).subtract(const Duration(milliseconds: 1));
    return (db.select(db.expenses)
          ..where((t) => t.date.isBetweenValues(start, end))
          ..orderBy([
            (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<int> addExpense({
    required String name,
    required String category,
    required double amount,
    required String type, // 'expense' or 'income'
    DateTime? date,
    bool isOverLimit = false,
    bool isPaid = true,
  }) {
    return db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            name: name,
            category: category,
            amount: amount,
            type: type,
            date: date ?? DateTime.now(),
            isOverLimit: Value(isOverLimit),
            isPaid: Value(isPaid),
          ),
        );
  }

  Future<bool> togglePaidStatus(int id, bool isPaid) async {
    final expense = await (db.select(db.expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (expense == null) return false;
    return db.update(db.expenses).replace(expense.copyWith(isPaid: isPaid));
  }

  Future<void> ensureMonthlySalaryPinned(double salaryAmount, DateTime now) async {
    try {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
      final existingSalary = await (db.select(db.expenses)
            ..where((t) => t.date.isBetweenValues(start, end) & t.type.equals('income') & t.name.equals('Monthly Salary')))
          .getSingleOrNull();

      if (existingSalary == null) {
        await db.into(db.expenses).insert(
              ExpensesCompanion.insert(
                name: 'Monthly Salary',
                category: 'Income',
                amount: salaryAmount,
                type: 'income',
                date: DateTime(now.year, now.month, 1, 9, 0),
                isPaid: const Value(true),
                isOverLimit: const Value(false),
              ),
            );
      }
    } catch (_) {
      // Gracefully handle any initial database locks or schema timing gaps
    }
  }


  Future<bool> updateExpense(Expense expense) {
    return db.update(db.expenses).replace(expense);
  }

  Future<int> deleteExpense(int id) {
    return (db.delete(db.expenses)..where((t) => t.id.equals(id))).go();
  }

  // --- Presets ("Regulars") ---

  Stream<List<Preset>> watchAllPresets() {
    return (db.select(db.presets)
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Stream<List<Preset>> watchPresetsByType(String type) {
    return (db.select(db.presets)
          ..where((t) => t.type.equals(type))
          ..orderBy([
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Future<int> addPreset({
    required String name,
    required String category,
    required double defaultAmount,
    String type = 'expense',
  }) {
    return db.into(db.presets).insert(
          PresetsCompanion.insert(
            name: name,
            category: category,
            defaultAmount: defaultAmount,
            type: Value(type),
          ),
        );
  }

  Future<bool> updatePreset(Preset preset) {
    return db.update(db.presets).replace(preset);
  }

  Future<int> deletePreset(int id) {
    return (db.delete(db.presets)..where((t) => t.id.equals(id))).go();
  }
}
