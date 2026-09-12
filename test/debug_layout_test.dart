import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_application_1/repositories/expense_repository.dart';
import 'package:flutter_application_1/database/app_database.dart';
import 'package:flutter_application_1/providers/expense_provider.dart';
import 'package:flutter_application_1/providers/profile_provider.dart';
import 'package:flutter_application_1/screens/auth/splash_screen.dart';
import 'package:flutter_application_1/screens/auth/onboarding_screen.dart';
import 'package:flutter_application_1/screens/main_navigation_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('Test MainNavigationScreen with populated expenses and pinned salary', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_logged_in': true,
      'auth_onboarded': true,
      'user_email': 'test@test.com',
      'user_monthly_salary': 50000.0,
      'user_daily_target': 1000.0,
      'user_monthly_target': 30000.0,
      'user_savings_target': 20000.0,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    // Add some expenses:
    final repo = ExpenseRepository(db);
    await repo.addExpense(
      name: 'Monthly Salary',
      category: 'Salary',
      amount: 50000.0,
      type: 'income',
      date: DateTime.now(),
      isPaid: true,
    );
    await repo.addExpense(
      name: 'Grocery Store Shopping With Very Long Name That Might Wrap',
      category: 'Groceries',
      amount: 450.0,
      type: 'expense',
      date: DateTime.now(),
    );
    await repo.addExpense(
      name: 'Yesterday Lunch',
      category: 'Food',
      amount: 150.0,
      type: 'expense',
      date: DateTime.now().subtract(const Duration(days: 1)),
    );
    await repo.addExpense(
      name: 'Last Month Rent',
      category: 'Housing',
      amount: 12000.0,
      type: 'expense',
      date: DateTime(DateTime.now().year, DateTime.now().month - 1, 15),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainNavigationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Test SplashScreen navigation flow', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_logged_in': false,
      'auth_onboarded': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await db.close();
  });

  testWidgets('Test OnboardingScreen layout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await db.close();
  });
}
