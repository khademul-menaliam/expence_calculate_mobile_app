import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/database/app_database.dart';
import 'package:flutter_application_1/screens/expenses/transaction_calendar_dialog.dart';

void main() {
  testWidgets('TransactionCalendarDialog renders active days (light) and empty days (shadow)', (tester) async {
    final testDate = DateTime(2026, 9, 12);
    final expenses = [
      Expense(
        id: 1,
        name: 'Grocery',
        category: 'Food',
        amount: 250.0,
        type: 'expense',
        date: DateTime(2026, 9, 12, 10, 0),
        isOverLimit: false,
        isPaid: true,
      ),
      Expense(
        id: 2,
        name: 'Salary',
        category: 'Salary',
        amount: 20000.0,
        type: 'income',
        date: DateTime(2026, 9, 12, 9, 0),
        isOverLimit: false,
        isPaid: true,
      ),
      Expense(
        id: 3,
        name: 'Coffee',
        category: 'Drinks',
        amount: 50.0,
        type: 'expense',
        date: DateTime(2026, 9, 5, 14, 0),
        isOverLimit: false,
        isPaid: true,
      ),
    ];

    DateTime? selectedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                selectedResult = await TransactionCalendarDialog.show(
                  context,
                  initialDate: testDate,
                  expenses: expenses,
                  currencySymbol: '৳',
                );
              },
              child: const Text('Open Calendar'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open Calendar'));
    await tester.pumpAndSettle();

    // Verify header and legend are displayed
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Active (Light)'), findsOneWidget);
    expect(find.text('Empty (Shadow)'), findsOneWidget);

    // Verify selected date details preview shows both income and expense for Sep 12
    expect(find.textContaining('Saturday, 12 Sep 2026'), findsOneWidget);
    expect(find.text('+৳ 20000.00'), findsOneWidget);
    expect(find.text('−৳ 250.00'), findsOneWidget);
    expect(find.text('(2 entries)'), findsOneWidget);

    // Tap day 5 (which only has expense)
    final day5 = find.text('5');
    expect(day5, findsOneWidget);
    await tester.tap(day5);
    await tester.pumpAndSettle();

    // Verify day 5 details
    expect(find.textContaining('5 Sep 2026'), findsOneWidget);
    expect(find.text('−৳ 50.00'), findsOneWidget);
    expect(find.text('(1 entry)'), findsOneWidget);

    // Tap day 10 (which has no transactions - shadow day)
    final day10 = find.text('10');
    expect(day10, findsOneWidget);
    await tester.tap(day10);
    await tester.pumpAndSettle();

    expect(find.text('No expenses or income logged on this date.'), findsOneWidget);

    // Select date
    await tester.ensureVisible(find.text('Select Date'));
    await tester.tap(find.text('Select Date'));
    await tester.pumpAndSettle();

    expect(selectedResult, equals(DateTime(2026, 9, 10)));
  });
}
