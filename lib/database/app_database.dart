import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Presets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  RealColumn get defaultAmount => real()();
  TextColumn get type => text().withDefault(const Constant('expense'))(); // 'expense' or 'income'
  BoolColumn get isAutoAdd => boolean().withDefault(const Constant(false))();
  IntColumn get autoAddDay => integer().withDefault(const Constant(1))();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'expense' or 'income'
  DateTimeColumn get date => dateTime()();
  BoolColumn get isOverLimit => boolean().withDefault(const Constant(false))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(true))();
}

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get targetCost => real().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active' or 'done'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [Presets, Expenses, Goals])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(presets, presets.type);
        }
        if (from < 3) {
          await m.addColumn(expenses, expenses.isOverLimit);
          await m.addColumn(expenses, expenses.isPaid);
        }
        if (from < 4) {
          await m.addColumn(presets, presets.isAutoAdd);
          await m.addColumn(presets, presets.autoAddDay);
        }
      },
      beforeOpen: (details) async {
        if (details.wasCreated) {
          await into(presets).insert(
            PresetsCompanion.insert(
              name: 'Coffee',
              category: 'Food & Drink',
              defaultAmount: 4.50,
              type: const Value('expense'),
            ),
          );
          await into(presets).insert(
            PresetsCompanion.insert(
              name: 'Lunch',
              category: 'Food & Drink',
              defaultAmount: 12.00,
              type: const Value('expense'),
            ),
          );
          await into(presets).insert(
            PresetsCompanion.insert(
              name: 'Transport',
              category: 'Commute',
              defaultAmount: 3.50,
              type: const Value('expense'),
            ),
          );
          await into(presets).insert(
            PresetsCompanion.insert(
              name: 'Salary',
              category: 'Income',
              defaultAmount: 2500.00,
              type: const Value('income'),
              isAutoAdd: const Value(true),
              autoAddDay: const Value(1),
            ),
          );
          await into(presets).insert(
            PresetsCompanion.insert(
              name: 'Freelance',
              category: 'Income',
              defaultAmount: 300.00,
              type: const Value('income'),
            ),
          );
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_expense_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
