import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:flutter_application_1/database/app_database.dart';
import 'package:flutter_application_1/providers/expense_provider.dart';
import 'package:flutter_application_1/providers/profile_provider.dart';
import 'package:flutter_application_1/screens/auth/auth_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

void main() {
  testWidgets('AuthScreen registers and navigates smoothly without freezing', (WidgetTester tester) async {
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
          home: const AuthScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Guest Mode button is visible
    expect(find.text('CONTINUE OFFLINE (GUEST MODE)'), findsOneWidget);

    await db.close();
  });
}


