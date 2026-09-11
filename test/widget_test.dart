import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_application_1/database/app_database.dart';
import 'package:flutter_application_1/providers/expense_provider.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App loads cleanly with Expenses & Goals tabs', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Daily Expenses'), findsOneWidget);
    expect(find.text('NET BALANCE'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);

    await db.close();
  });
}
