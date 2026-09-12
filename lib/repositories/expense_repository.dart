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

  Future<int> addExpense({
    required String name,
    required String category,
    required double amount,
    required String type, // 'expense' or 'income'
    DateTime? date,
  }) {
    return db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            name: name,
            category: category,
            amount: amount,
            type: type,
            date: date ?? DateTime.now(),
          ),
        );
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
