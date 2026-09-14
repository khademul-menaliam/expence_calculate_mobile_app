import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import 'edit_expense_dialog.dart';

class QuickAddPopup extends ConsumerStatefulWidget {
  const QuickAddPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: QuickAddPopup(),
      ),
    );
  }

  @override
  ConsumerState<QuickAddPopup> createState() => _QuickAddPopupState();
}

class _QuickAddPopupState extends ConsumerState<QuickAddPopup> {
  String _type = 'expense'; // 'expense' or 'income'
  DateTime _selectedDate = DateTime.now();

  // Manual "Other" input controllers
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');
  final _amountController = TextEditingController();
  final _sessionScrollController = ScrollController();
  final _otherFormKey = GlobalKey<FormState>();

  // Running session log inside popup
  final List<_SessionItem> _sessionAddedItems = [];

  double get _sessionTotal {
    return _sessionAddedItems.fold(0.0, (sum, item) {
      return item.type == 'expense' ? sum + item.amount : sum - item.amount;
    });
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dtOnly = DateTime(dt.year, dt.month, dt.day);

    if (dtOnly.isAtSameMomentAs(today)) {
      return 'Today (${DateFormat('MMM d').format(dt)})';
    } else if (dtOnly.isAtSameMomentAs(yesterday)) {
      return 'Yesterday (${DateFormat('MMM d').format(dt)})';
    } else {
      return DateFormat('MMM d, yyyy').format(dt);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    _sessionScrollController.dispose();
    super.dispose();
  }

  bool _isAdding = false;
  _LimitNotice? _activeLimitNotice;

  void _checkPostAddLimitAlert({
    required bool dailyExceeded,
    required bool monthlyExceeded,
  }) {
    if (_type != 'expense' || (!dailyExceeded && !monthlyExceeded)) return;

    final selectedDateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    // Check if limit alert is muted for this specific date
    final prefs = ref.read(sharedPreferencesProvider);
    final mutedDate = prefs.getString('mute_limit_alert_date');
    if (mutedDate == selectedDateStr) {
      return;
    }

    // Build notifications and messages
    final List<String> messages = [];
    if (dailyExceeded) {
      messages.add('You have reached your daily target, so on next day be careful you can reduce your expense.');
    }
    if (monthlyExceeded) {
      messages.add('You have reached your monthly target, so for the remaining days of this month be careful and reduce your expense.');
    }

    final fullMessage = messages.join('\n\n');

    // Trigger local push notification safely in background without blocking UI thread
    NotificationService().showBudgetExceededNotification(
      title: 'Target Limit Reached',
      body: messages.first,
    ).catchError((_) {});

    if (!mounted) return;

    setState(() {
      _activeLimitNotice = _LimitNotice(
        message: fullMessage,
        dateStr: selectedDateStr,
      );
    });
  }

  Future<void> _addPresetEntry(Preset preset, double amount) async {
    if (_isAdding) return;
    setState(() => _isAdding = true);

    try {
      final stats = ref.read(expenseStatsProvider);
      final isToday = _selectedDate.year == DateTime.now().year &&
          _selectedDate.month == DateTime.now().month &&
          _selectedDate.day == DateTime.now().day;
      final projectedMonthly = stats.monthTotal + amount;
      final projectedDaily = isToday ? stats.todayTotal + amount : amount;
      final dailyExceeded = _type == 'expense' && isToday && projectedDaily > stats.dailyTarget;
      final monthlyExceeded = _type == 'expense' && projectedMonthly > stats.monthlyTarget;
      final isOverLimit = dailyExceeded || monthlyExceeded;

      final repository = ref.read(expenseRepositoryProvider);
      final id = await repository.addExpense(
        name: preset.name,
        category: preset.category,
        amount: amount,
        type: _type,
        date: _selectedDate,
        isOverLimit: isOverLimit,
      );

      if (!mounted) return;

      setState(() {
        _sessionAddedItems.insert(
          0,
          _SessionItem(
            id: id,
            name: preset.name,
            category: preset.category,
            amount: amount,
            type: _type,
            date: _selectedDate,
          ),
        );
      });

      if (isOverLimit) {
        _checkPostAddLimitAlert(
          dailyExceeded: dailyExceeded,
          monthlyExceeded: monthlyExceeded,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _addOtherEntry() async {
    if (_isAdding) return;
    if (!_otherFormKey.currentState!.validate()) return;
    setState(() => _isAdding = true);

    try {
      final name = _nameController.text.trim();
      final category = _categoryController.text.trim();
      final sanitizedAmount = _amountController.text.trim().replaceAll(',', '.');
      final amount = double.tryParse(sanitizedAmount) ?? 0.0;

      final stats = ref.read(expenseStatsProvider);
      final isToday = _selectedDate.year == DateTime.now().year &&
          _selectedDate.month == DateTime.now().month &&
          _selectedDate.day == DateTime.now().day;
      final projectedMonthly = stats.monthTotal + amount;
      final projectedDaily = isToday ? stats.todayTotal + amount : amount;
      final dailyExceeded = _type == 'expense' && isToday && projectedDaily > stats.dailyTarget;
      final monthlyExceeded = _type == 'expense' && projectedMonthly > stats.monthlyTarget;
      final isOverLimit = dailyExceeded || monthlyExceeded;

      final repository = ref.read(expenseRepositoryProvider);
      final id = await repository.addExpense(
        name: name,
        category: category,
        amount: amount,
        type: _type,
        date: _selectedDate,
        isOverLimit: isOverLimit,
      );

      if (!mounted) return;

      setState(() {
        _sessionAddedItems.insert(
          0,
          _SessionItem(
            id: id,
            name: name,
            category: category,
            amount: amount,
            type: _type,
            date: _selectedDate,
          ),
        );
        _nameController.clear();
        _amountController.clear();
        _categoryController.text = 'General';
      });

      if (isOverLimit) {
        _checkPostAddLimitAlert(
          dailyExceeded: dailyExceeded,
          monthlyExceeded: monthlyExceeded,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }


  Future<void> _removeSessionItem(_SessionItem item) async {
    final repository = ref.read(expenseRepositoryProvider);
    await repository.deleteExpense(item.id);

    setState(() {
      _sessionAddedItems.removeWhere((i) => i.id == item.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${item.name}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _editSessionItem(_SessionItem item) async {
    final expense = Expense(
      id: item.id,
      name: item.name,
      category: item.category,
      amount: item.amount,
      type: item.type,
      date: item.date,
      isPaid: true,
      isOverLimit: false,
    );

    await EditExpenseDialog.show(context, expense);

    if (!mounted) return;

    final db = ref.read(databaseProvider);
    final updated = await (db.select(db.expenses)..where((t) => t.id.equals(item.id))).getSingleOrNull();

    if (mounted) {
      setState(() {
        final index = _sessionAddedItems.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          if (updated != null) {
            _sessionAddedItems[index] = _SessionItem(
              id: updated.id,
              name: updated.name,
              category: updated.category,
              amount: updated.amount,
              type: updated.type,
              date: updated.date,
            );
          } else {
            _sessionAddedItems.removeAt(index);
          }
        }
      });
    }
  }

  void _showPresetAmountOverrideDialog(Preset preset) {
    final overrideController = TextEditingController(text: preset.defaultAmount.toStringAsFixed(2));
    final dialogKey = GlobalKey<FormState>();

    final currencySymbol = ref.read(currencyProvider).symbol;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Override amount for "${preset.name}"'),
          content: Form(
            key: dialogKey,
            child: TextFormField(
              controller: overrideController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'One-time Amount',
                prefixText: '$currencySymbol ',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Enter amount';
                final sanitized = val.trim().replaceAll(',', '.');
                final p = double.tryParse(sanitized);
                if (p == null || p <= 0) return 'Enter valid positive amount';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 44)),
              onPressed: () {
                if (dialogKey.currentState!.validate()) {
                  final sanitized = overrideController.text.trim().replaceAll(',', '.');
                  final overrideAmount = double.tryParse(sanitized) ?? preset.defaultAmount;
                  Navigator.of(dialogCtx).pop();
                  _addPresetEntry(preset, overrideAmount);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(presetsByTypeStreamProvider(_type));
    final currency = ref.watch(currencyProvider);
    final isExpense = _type == 'expense';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header with Title, Type Segment & Close Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              color: AppTheme.cardBg,
              child: Row(
                children: [
                  const Text(
                    'Quick Add',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Type Selector Segmented Control
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _TypeTab(
                          label: 'Expense',
                          isSelected: _type == 'expense',
                          onTap: () => setState(() => _type = 'expense'),
                          color: AppTheme.expenseColor,
                        ),
                        _TypeTab(
                          label: 'Income',
                          isSelected: _type == 'income',
                          onTap: () => setState(() => _type = 'income'),
                          color: AppTheme.incomeColor,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Date Selector Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primaryAccent),
                const SizedBox(width: 6),
                Text(
                  'Logging for: ${_dateLabel(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          DateTime.now().hour,
                          DateTime.now().minute,
                        );
                      });
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.edit_calendar, size: 14, color: AppTheme.primaryAccent),
                        SizedBox(width: 4),
                        Text(
                          'Change Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Main Scrollable Area (wrapping content dynamically)
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                if (_activeLimitNotice != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.expenseColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.expenseColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.expenseColor, size: 20),
                            const SizedBox(width: 6),
                            const Text(
                              'Target Limit Reached',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.expenseColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() => _activeLimitNotice = null);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _activeLimitNotice!.message,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                final dateStr = _activeLimitNotice?.dateStr;
                                if (dateStr != null) {
                                  final prefs = ref.read(sharedPreferencesProvider);
                                  await prefs.setString('mute_limit_alert_date', dateStr);
                                }
                                if (mounted) {
                                  setState(() => _activeLimitNotice = null);
                                }
                              },
                              child: const Text(
                                "Don't show this today",
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.expenseColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () {
                                setState(() => _activeLimitNotice = null);
                              },
                              child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Section: Presets
                Row(
                  children: [
                    Text(
                      isExpense ? 'EXPENSE PRESETS (TAP TO ADD)' : 'INCOME PRESETS (TAP TO ADD)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Long-press to adjust amount',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                presetsAsync.when(
                  data: (presets) {
                    final availablePresets = presets.toList();

                    if (availablePresets.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          isExpense
                              ? 'No expense presets configured yet. Use manual entry below.'
                              : 'No income presets configured yet. Use manual entry below.',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availablePresets.map((preset) {
                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _isAdding ? null : () => _addPresetEntry(preset, preset.defaultAmount),
                            onLongPress: _isAdding ? null : () => _showPresetAmountOverrideDialog(preset),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isExpense
                                    ? AppTheme.accentLight.withValues(alpha: 0.4)
                                    : AppTheme.incomeColor.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: isExpense
                                      ? AppTheme.primaryAccent.withValues(alpha: 0.3)
                                      : AppTheme.incomeColor.withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preset.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        currency.format(preset.defaultAmount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isExpense ? AppTheme.primaryAccent : AppTheme.incomeColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 18,
                                    color: isExpense ? AppTheme.primaryAccent : AppTheme.incomeColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 16),

                // Section: Other (Manual Entry)
                Text(
                  'MANUAL ENTRY (${_type.toUpperCase()})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                Form(
                  key: _otherFormKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Name',
                                hintText: isExpense ? 'e.g. Parking' : 'e.g. Consulting',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                prefixText: '${currency.symbol} ',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                final sanitized = v.trim().replaceAll(',', '.');
                                final p = double.tryParse(sanitized);
                                if (p == null || p <= 0) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                hintText: isExpense ? 'e.g. Transport' : 'e.g. Freelance, Gift',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(100, 48),
                              backgroundColor: AppTheme.cardBg,
                            ),
                            onPressed: _isAdding ? null : _addOtherEntry,
                            icon: _isAdding
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add, size: 18),
                            label: const Text('Add Entry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Running Session Summary ("Added in this Session")
                if (_sessionAddedItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ADDED IN THIS SESSION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        'Session Net: ${currency.format(_sessionTotal)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Builder(
                        builder: (context) {
                          final groupedMap = _groupedSessionItems;
                          final dateKeys = groupedMap.keys.toList();

                          return Scrollbar(
                            controller: _sessionScrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _sessionScrollController,
                              shrinkWrap: true,
                              itemCount: dateKeys.length,
                              itemBuilder: (context, groupIndex) {
                                final dateHeader = dateKeys[groupIndex];
                                final items = groupedMap[dateHeader]!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Subtle Date Group Header
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      color: const Color(0xFFF1F5F9),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.primaryAccent),
                                          const SizedBox(width: 4),
                                          Text(
                                            dateHeader,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Items inside this date group
                                    Column(
                                      children: List.generate(items.length, (itemIndex) {
                                        final item = items[itemIndex];
                                        final itemIsExpense = item.type == 'expense';
                                        return Column(
                                          children: [
                                            if (itemIndex > 0) const Divider(height: 1, color: AppTheme.border),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              child: Row(
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            item.name,
                                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFF1F5F9),
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                                                            ),
                                                            child: Text(
                                                              item.category,
                                                              style: const TextStyle(
                                                                color: AppTheme.textSecondary,
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.access_time, size: 11, color: AppTheme.textSecondary),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            DateFormat.jm().format(item.date),
                                                            style: const TextStyle(
                                                              color: AppTheme.textSecondary,
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    '${itemIsExpense ? "-" : "+"}${currency.format(item.amount)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                      color: itemIsExpense ? AppTheme.expenseColor : AppTheme.incomeColor,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryAccent),
                                                    tooltip: 'Edit entry',
                                                    onPressed: () => _editSessionItem(item),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.expenseColor),
                                                    tooltip: 'Remove from session',
                                                    onPressed: () => _removeSessionItem(item),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Map<String, List<_SessionItem>> get _groupedSessionItems {
    final Map<String, List<_SessionItem>> grouped = {};
    for (final item in _sessionAddedItems) {
      final key = _sessionDateHeader(item.date);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  String _sessionDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target.isAtSameMomentAs(today)) {
      return 'Today (${DateFormat('MMM d').format(dt)})';
    } else if (target.isAtSameMomentAs(yesterday)) {
      return 'Yesterday (${DateFormat('MMM d').format(dt)})';
    } else {
      return DateFormat('EEE, MMM d, yyyy').format(dt);
    }
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [const BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SessionItem {
  final int id;
  final String name;
  final String category;
  final double amount;
  final String type;
  final DateTime date;

  _SessionItem({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
  });
}

class _LimitNotice {
  final String message;
  final String dateStr;

  _LimitNotice({
    required this.message,
    required this.dateStr,
  });
}
