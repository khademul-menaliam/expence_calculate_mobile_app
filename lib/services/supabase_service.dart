import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import '../repositories/profile_repository.dart';

class SyncResult {
  final bool success;
  final String message;
  final int expensesCount;
  final int presetsCount;
  final int goalsCount;

  const SyncResult({
    required this.success,
    required this.message,
    this.expensesCount = 0,
    this.presetsCount = 0,
    this.goalsCount = 0,
  });
}

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Supabase Configuration
  // Paste your Supabase project URL and anon public key here:
  static const String supabaseUrl = 'https://ulrfugznftqrdnmuqtdr.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVscmZ1Z3puZnRxcmRubXVxdGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4Nzc3MDMsImV4cCI6MjEwNzQ1MzcwM30.obkrllgSWWLd9cYY1Z3KwhZ8WDHOiAaMSTvZUpWt4mM';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE');

  SupabaseClient? get client {
    if (_initialized) {
      return Supabase.instance.client;
    }
    try {
      final c = Supabase.instance.client;
      _initialized = true;
      return c;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => client?.auth.currentUser;

  Future<void> init() async {
    if (_initialized) return;

    if (!isConfigured) {
      debugPrint('[SupabaseService] Not configured yet. Running in 100% offline mode.');
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('[SupabaseService] Supabase successfully initialized.');
    } catch (e) {
      debugPrint('[SupabaseService] Initialization note: $e');
      try {
        Supabase.instance.client;
        _initialized = true;
      } catch (_) {}
    }
  }

  // Cloud Auth Helpers
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
  }) async {
    if (!isConfigured || client == null) return null;
    return await client!.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured || client == null) return null;
    return await client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (client != null) {
      await client!.auth.signOut();
    }
  }

  /// Uploads local Drift expenses, presets, and goals to Supabase and downloads cloud records
  Future<SyncResult> syncLocalDataToCloud({
    required AppDatabase db,
    UserProfile? profile,
  }) async {
    if (!isConfigured || client == null) {
      return const SyncResult(success: false, message: 'Cloud service is not connected.');
    }

    var user = currentUser;
    // Auto-restore session using saved credentials if currentUser is null
    if (user == null &&
        profile != null &&
        profile.userEmail.isNotEmpty &&
        profile.userEmail != 'local_user@offline') {
      if (profile.userPassword.isNotEmpty) {
        try {
          final res = await signIn(email: profile.userEmail, password: profile.userPassword);
          user = res?.user ?? currentUser;
        } catch (_) {
          try {
            final res = await signUp(email: profile.userEmail, password: profile.userPassword);
            user = res?.user ?? currentUser;
          } catch (_) {}
        }
      }
    }

    if (user == null) {
      return const SyncResult(
        success: false,
        message: 'Cloud session not active. Please sign in or register to sync.',
      );
    }

    int expensesCount = 0;
    int presetsCount = 0;
    int goalsCount = 0;

    try {
      // 1. Sync Profile targets
      if (profile != null) {
        await client?.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? profile.userEmail,
          'monthly_salary': profile.monthlySalary,
          'daily_expense_target': profile.dailyExpenseTarget,
          'monthly_expense_target': profile.monthlyExpenseTarget,
          'monthly_savings_target': profile.monthlySavingsTarget,
        });
      }

      // 2. Fetch local expenses and upload
      final localExpenses = await db.select(db.expenses).get();
      if (localExpenses.isNotEmpty) {
        final cloudExpensesResponse = await client!
            .from('expenses')
            .select('name, date, amount')
            .eq('user_id', user.id);

        final existingSet = <String>{};
        for (final row in cloudExpensesResponse) {
          existingSet.add('${row['name']}_${row['date']}_${row['amount']}');
        }

        final toInsert = <Map<String, dynamic>>[];
        for (final exp in localExpenses) {
          final key = '${exp.name}_${exp.date.toIso8601String()}_${exp.amount}';
          if (!existingSet.contains(key)) {
            toInsert.add({
              'user_id': user.id,
              'name': exp.name,
              'category': exp.category,
              'amount': exp.amount,
              'type': exp.type,
              'date': exp.date.toIso8601String(),
              'is_over_limit': exp.isOverLimit,
              'is_paid': exp.isPaid,
            });
          }
        }

        if (toInsert.isNotEmpty) {
          await client!.from('expenses').insert(toInsert);
          expensesCount = toInsert.length;
        }
      }

      // 3. Fetch local presets and upload
      final localPresets = await db.select(db.presets).get();
      if (localPresets.isNotEmpty) {
        final cloudPresets = await client!
            .from('presets')
            .select('name, category')
            .eq('user_id', user.id);

        final existingPresets = <String>{};
        for (final row in cloudPresets) {
          existingPresets.add('${row['name']}_${row['category']}');
        }

        final presetsToInsert = <Map<String, dynamic>>[];
        for (final p in localPresets) {
          final key = '${p.name}_${p.category}';
          if (!existingPresets.contains(key)) {
            presetsToInsert.add({
              'user_id': user.id,
              'name': p.name,
              'category': p.category,
              'default_amount': p.defaultAmount,
              'type': p.type,
              'is_auto_add': p.isAutoAdd,
              'auto_add_day': p.autoAddDay,
            });
          }
        }

        if (presetsToInsert.isNotEmpty) {
          await client!.from('presets').insert(presetsToInsert);
          presetsCount = presetsToInsert.length;
        }
      }

      // 4. Fetch local goals and upload
      final localGoals = await db.select(db.goals).get();
      if (localGoals.isNotEmpty) {
        final cloudGoals = await client!
            .from('goals')
            .select('name')
            .eq('user_id', user.id);

        final existingGoals = <String>{};
        for (final row in cloudGoals) {
          existingGoals.add('${row['name']}');
        }

        final goalsToInsert = <Map<String, dynamic>>[];
        for (final g in localGoals) {
          if (!existingGoals.contains(g.name)) {
            goalsToInsert.add({
              'user_id': user.id,
              'name': g.name,
              'target_cost': g.targetCost,
              'note': g.note,
              'target_date': g.targetDate?.toIso8601String(),
              'status': g.status,
              'created_at': g.createdAt.toIso8601String(),
              'completed_at': g.completedAt?.toIso8601String(),
            });
          }
        }

        if (goalsToInsert.isNotEmpty) {
          await client!.from('goals').insert(goalsToInsert);
          goalsCount = goalsToInsert.length;
        }
      }

      // 5. Download missing cloud expenses into local SQLite (multi-device merge)
      int downloadedExpenses = 0;
      final allCloudExpenses = await client!
          .from('expenses')
          .select()
          .eq('user_id', user.id);

      final localKeys = localExpenses
          .map((e) => '${e.name}_${e.date.toIso8601String()}_${e.amount}')
          .toSet();

      for (final row in allCloudExpenses) {
        final name = row['name'] as String? ?? 'Expense';
        final dateStr = row['date'] as String?;
        final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final key = '${name}_${date.toIso8601String()}_$amount';
        if (!localKeys.contains(key)) {
          await db.into(db.expenses).insert(
            ExpensesCompanion.insert(
              name: name,
              category: row['category'] as String? ?? 'General',
              amount: amount,
              type: row['type'] as String? ?? 'expense',
              date: date,
              isOverLimit: drift.Value(row['is_over_limit'] as bool? ?? false),
              isPaid: drift.Value(row['is_paid'] as bool? ?? true),
            ),
          );
          localKeys.add(key);
          downloadedExpenses++;
        }
      }

      final totalUploaded = expensesCount + presetsCount + goalsCount;
      String summaryMsg;
      if (totalUploaded > 0 && downloadedExpenses > 0) {
        summaryMsg = 'Synced! Uploaded $totalUploaded items & downloaded $downloadedExpenses cloud expenses.';
      } else if (totalUploaded > 0) {
        summaryMsg = 'Uploaded $expensesCount expenses, $presetsCount presets, $goalsCount goals to cloud!';
      } else if (downloadedExpenses > 0) {
        summaryMsg = 'Downloaded $downloadedExpenses cloud expenses to this device!';
      } else {
        summaryMsg = 'All data is synchronized and up to date with cloud.';
      }

      return SyncResult(
        success: true,
        message: summaryMsg,
        expensesCount: expensesCount,
        presetsCount: presetsCount,
        goalsCount: goalsCount,
      );
    } catch (e) {
      debugPrint('[SupabaseService] Sync error: $e');
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }
}
