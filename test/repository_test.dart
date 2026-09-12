import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_application_1/database/app_database.dart';
import 'package:flutter_application_1/repositories/expense_repository.dart';
import 'package:flutter_application_1/repositories/goal_repository.dart';

void main() {
  late AppDatabase db;
  late ExpenseRepository expenseRepo;
  late GoalRepository goalRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    expenseRepo = ExpenseRepository(db);
    goalRepo = GoalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Expense & Preset Repository Tests', () {
    test('Add and stream presets', () async {
      final initialPresets = await expenseRepo.watchAllPresets().first;
      final initialCount = initialPresets.length;

      await expenseRepo.addPreset(
        name: 'Custom Preset',
        category: 'Food',
        defaultAmount: 3.50,
        type: 'expense',
      );

      final presets = await expenseRepo.watchAllPresets().first;
      expect(presets.length, equals(initialCount + 1));
      expect(presets.any((p) => p.name == 'Custom Preset'), isTrue);
    });

    test('Add expense and verify live calculations stream', () async {
      await expenseRepo.addExpense(
        name: 'Lunch',
        category: 'Food',
        amount: 15.00,
        type: 'expense',
      );

      await expenseRepo.addExpense(
        name: 'Freelance Pay',
        category: 'Income',
        amount: 100.00,
        type: 'income',
      );

      final expenses = await expenseRepo.watchAllExpenses().first;
      expect(expenses.length, equals(2));

      final expenseItems = expenses.where((e) => e.type == 'expense');
      final incomeItems = expenses.where((e) => e.type == 'income');

      expect(expenseItems.first.amount, equals(15.00));
      expect(incomeItems.first.amount, equals(100.00));
    });

    test('Updating preset default amount does NOT change existing expenses', () async {
      await expenseRepo.addPreset(
        name: 'Bus',
        category: 'Transport',
        defaultAmount: 2.00,
      );

      await expenseRepo.addExpense(
        name: 'Bus',
        category: 'Transport',
        amount: 2.00,
        type: 'expense',
      );

      final presets = await expenseRepo.watchAllPresets().first;
      final p = presets.first;

      await expenseRepo.updatePreset(p.copyWith(defaultAmount: 3.00));

      final expenses = await expenseRepo.watchAllExpenses().first;
      expect(expenses.first.amount, equals(2.00)); // Unchanged past snapshot
    });
  });

  group('Goal Repository Tests', () {
    test('Add goal defaults to active', () async {
      await goalRepo.addGoal(
        name: 'New Laptop',
        targetCost: 1200.00,
      );

      final activeGoals = await goalRepo.watchActiveGoals().first;
      expect(activeGoals.length, equals(1));
      expect(activeGoals.first.name, equals('New Laptop'));
      expect(activeGoals.first.status, equals('active'));
    });

    test('Mark complete moves goal to done tab and sets completedAt', () async {
      final id = await goalRepo.addGoal(name: 'Trip to Tokyo');
      
      await goalRepo.markGoalComplete(id);

      final activeGoals = await goalRepo.watchActiveGoals().first;
      final doneGoals = await goalRepo.watchDoneGoals().first;

      expect(activeGoals.isEmpty, isTrue);
      expect(doneGoals.length, equals(1));
      expect(doneGoals.first.name, equals('Trip to Tokyo'));
      expect(doneGoals.first.status, equals('done'));
      expect(doneGoals.first.completedAt, isNotNull);
    });

    test('Un-completing done goal restores it to active list', () async {
      final id = await goalRepo.addGoal(name: 'Read 10 Books');
      await goalRepo.markGoalComplete(id);

      await goalRepo.markGoalUncomplete(id);

      final activeGoals = await goalRepo.watchActiveGoals().first;
      final doneGoals = await goalRepo.watchDoneGoals().first;

      expect(activeGoals.length, equals(1));
      expect(doneGoals.isEmpty, isTrue);
      expect(activeGoals.first.completedAt, isNull);
    });

    test('Delete goal removes record', () async {
      final id = await goalRepo.addGoal(name: 'Temporary Goal');
      await goalRepo.deleteGoal(id);

      final activeGoals = await goalRepo.watchActiveGoals().first;
      expect(activeGoals.isEmpty, isTrue);
    });
  });
}
