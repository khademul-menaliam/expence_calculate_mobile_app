import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../theme/app_theme.dart';

/// Summary of transactions for a single calendar day.
class DayTransactionSummary {
  final double totalIncome;
  final double totalExpense;
  final int count;
  final bool hasIncome;
  final bool hasExpense;

  const DayTransactionSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.count,
    required this.hasIncome,
    required this.hasExpense,
  });

  bool get hasTransactions => count > 0;
}

class TransactionCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final List<Expense> expenses;
  final String currencySymbol;

  const TransactionCalendarDialog({
    super.key,
    required this.initialDate,
    required this.expenses,
    this.currencySymbol = '৳',
  });

  /// Static helper to display the dialog.
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    required List<Expense> expenses,
    String currencySymbol = '৳',
  }) {
    return showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (context) => TransactionCalendarDialog(
        initialDate: initialDate,
        expenses: expenses,
        currencySymbol: currencySymbol,
      ),
    );
  }

  @override
  State<TransactionCalendarDialog> createState() => _TransactionCalendarDialogState();
}

class _TransactionCalendarDialogState extends State<TransactionCalendarDialog> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  late Map<String, DayTransactionSummary> _summaryMap;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _buildSummaryMap();
  }

  void _buildSummaryMap() {
    final map = <String, _DayAccumulator>{};

    for (final exp in widget.expenses) {
      // Exclude unpaid entries from calendar totals
      if (!exp.isPaid) continue;

      final key = _dayKey(exp.date);
      final acc = map.putIfAbsent(key, () => _DayAccumulator());
      acc.count++;
      if (exp.type == 'income') {
        acc.totalIncome += exp.amount;
        acc.hasIncome = true;
      } else {
        acc.totalExpense += exp.amount;
        acc.hasExpense = true;
      }
    }

    _summaryMap = map.map(
      (key, acc) => MapEntry(
        key,
        DayTransactionSummary(
          totalIncome: acc.totalIncome,
          totalExpense: acc.totalExpense,
          count: acc.count,
          hasIncome: acc.hasIncome,
          hasExpense: acc.hasExpense,
        ),
      ),
    );
  }

  String _dayKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  DayTransactionSummary? _getSummary(DateTime dt) {
    return _summaryMap[_dayKey(dt)];
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _displayedMonth = DateTime(now.year, now.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    // Monday = 1 ... Sunday = 7
    final leadingBlanks = (firstWeekday - 1) % 7;

    final selectedSummary = _getSummary(_selectedDate);

    return Dialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Month/Year and navigation
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month,
                        color: AppTheme.primaryAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(_displayedMonth),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Select a date to filter',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _goToToday,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryAccent,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _previousMonth,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Visual Legend (Lit up vs Shadowed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    runAlignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildLegendItem(
                        icon: Icons.wb_sunny_outlined,
                        label: 'Active (Light)',
                        color: AppTheme.primaryAccent,
                      ),
                      _buildLegendItem(
                        icon: Icons.circle,
                        label: 'Income',
                        color: AppTheme.incomeColor,
                        size: 8,
                      ),
                      _buildLegendItem(
                        icon: Icons.circle,
                        label: 'Expense',
                        color: AppTheme.expenseColor,
                        size: 8,
                      ),
                      _buildLegendItem(
                        icon: Icons.cloud_outlined,
                        label: 'Empty (Shadow)',
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Weekday Headers (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                    return SizedBox(
                      width: 36,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Calendar Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: leadingBlanks + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < leadingBlanks) {
                      return const SizedBox.shrink();
                    }

                    final dayNumber = index - leadingBlanks + 1;
                    final cellDate = DateTime(
                      _displayedMonth.year,
                      _displayedMonth.month,
                      dayNumber,
                    );
                    final summary = _getSummary(cellDate);
                    final hasTxn = summary != null && summary.hasTransactions;
                    final isSelected = cellDate == _selectedDate;
                    final isToday = cellDate == today;

                    return _buildCalendarCell(
                      cellDate: cellDate,
                      dayNumber: dayNumber,
                      hasTxn: hasTxn,
                      summary: summary,
                      isSelected: isSelected,
                      isToday: isToday,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Selected Day Details Preview Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selectedSummary != null && selectedSummary.hasTransactions
                        ? AppTheme.primaryAccent.withValues(alpha: 0.06)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedSummary != null && selectedSummary.hasTransactions
                          ? AppTheme.primaryAccent.withValues(alpha: 0.3)
                          : AppTheme.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  selectedSummary != null && selectedSummary.hasTransactions
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                                  size: 16,
                                  color: selectedSummary != null && selectedSummary.hasTransactions
                                      ? AppTheme.primaryAccent
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedDate == today) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TODAY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (selectedSummary != null && selectedSummary.hasTransactions) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (selectedSummary.hasIncome)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.incomeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '+${widget.currencySymbol} ${selectedSummary.totalIncome.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.incomeColor,
                                  ),
                                ),
                              ),
                            if (selectedSummary.hasExpense)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.expenseColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '−${widget.currencySymbol} ${selectedSummary.totalExpense.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.expenseColor,
                                  ),
                                ),
                              ),
                            Text(
                              '(${selectedSummary.count} ${selectedSummary.count == 1 ? 'entry' : 'entries'})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text(
                          'No expenses or income logged on this date.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(_selectedDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.filter_alt, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              selectedSummary != null && selectedSummary.hasTransactions
                                  ? 'Filter This Date'
                                  : 'Select Date',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required IconData icon,
    required String label,
    required Color color,
    double size = 12,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color == Colors.grey.shade500 ? AppTheme.textSecondary : color,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCell({
    required DateTime cellDate,
    required int dayNumber,
    required bool hasTxn,
    required DayTransactionSummary? summary,
    required bool isSelected,
    required bool isToday,
  }) {
    final BoxDecoration decoration;

    if (isSelected) {
      decoration = BoxDecoration(
        color: hasTxn ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryAccent, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryAccent.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
    } else if (hasTxn) {
      // LIGHT / ILLUMINATED CELL (Active Day)
      decoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (summary?.hasIncome ?? false)
              ? AppTheme.incomeColor.withValues(alpha: 0.4)
              : AppTheme.primaryAccent.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000), // black with 0.06 alpha
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      );
    } else {
      // SHADOWED / MUTED CELL (No Activity)
      decoration = BoxDecoration(
        color: const Color(0xFFEFEFF2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x0A000000), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000), // black with 0.04 alpha
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      );
    }

    final Color textColor;
    if (isSelected) {
      textColor = AppTheme.primaryAccent;
    } else if (hasTxn) {
      textColor = AppTheme.textPrimary;
    } else {
      textColor = Colors.grey.shade400;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = cellDate;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: decoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day Number
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasTxn || isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),

            const SizedBox(height: 2),

            // Activity Indicator Dots (Green for Income, Red for Expense)
            if (hasTxn && summary != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (summary.hasIncome)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.incomeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (summary.hasExpense)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.expenseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              )
            else if (isToday)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryAccent,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

class _DayAccumulator {
  double totalIncome = 0;
  double totalExpense = 0;
  int count = 0;
  bool hasIncome = false;
  bool hasExpense = false;
}
