import 'package:drift/drift.dart';
import '../database/app_database.dart';

class GoalRepository {
  final AppDatabase db;

  GoalRepository(this.db);

  Stream<List<Goal>> watchActiveGoals() {
    return (db.select(db.goals)
          ..where((t) => t.status.equals('active'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Stream<List<Goal>> watchDoneGoals() {
    return (db.select(db.goals)
          ..where((t) => t.status.equals('done'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.completedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<int> addGoal({
    required String name,
    double? targetCost,
    String? note,
    DateTime? targetDate,
  }) {
    return db.into(db.goals).insert(
          GoalsCompanion.insert(
            name: name,
            targetCost: Value(targetCost),
            note: Value(note),
            targetDate: Value(targetDate),
            status: const Value('active'),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> markGoalComplete(int id) {
    return (db.update(db.goals)..where((t) => t.id.equals(id))).write(
      GoalsCompanion(
        status: const Value('done'),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> markGoalUncomplete(int id) {
    return (db.update(db.goals)..where((t) => t.id.equals(id))).write(
      const GoalsCompanion(
        status: Value('active'),
        completedAt: Value(null),
      ),
    );
  }

  Future<bool> updateGoal(Goal goal) {
    return db.update(db.goals).replace(goal);
  }

  Future<int> deleteGoal(int id) {
    return (db.delete(db.goals)..where((t) => t.id.equals(id))).go();
  }
}
