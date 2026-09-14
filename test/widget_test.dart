import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_application_1/database/app_database.dart';
import 'package:flutter_application_1/providers/expense_provider.dart';
import 'package:flutter_application_1/providers/profile_provider.dart';
import 'package:flutter_application_1/screens/main_navigation_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('App loads cleanly with Dashboard, Goals, & Settings tabs', (WidgetTester tester) async {
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
          home: const MainNavigationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('MONTHLY SUMMARY'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await db.close();
  });

  testWidgets('QuickAddPopup allows multiple preset additions without Scrollbar assertion errors', (WidgetTester tester) async {
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
          home: const MainNavigationScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open Quick Add Popup
    await tester.tap(find.text('Quick Add'));
    await tester.pumpAndSettle();

    expect(find.text('EXPENSE PRESETS (TAP TO ADD)'), findsOneWidget);

    // Tap Coffee preset
    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    // Tap Lunch preset
    await tester.tap(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.text('ADDED IN THIS SESSION'), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
    expect(find.text('Lunch'), findsWidgets);

    await db.close();
  });
}
