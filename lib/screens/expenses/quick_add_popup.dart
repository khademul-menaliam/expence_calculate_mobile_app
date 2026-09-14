import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';

class QuickAddPopup extends ConsumerStatefulWidget {
  const QuickAddPopup({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (_) => const QuickAddPopup(),
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
    super.dispose();
  }

  Future<bool> _checkLimitAlert(double amount) async {
    if (_type != 'expense') return false;

    final stats = ref.read(expenseStatsProvider);
    final currency = ref.read(currencyProvider);
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    final projectedMonthly = stats.monthTotal + amount;
    final projectedDaily = isToday ? stats.todayTotal + amount : amount;

    final monthlyExceeded = projectedMonthly > stats.monthlyTarget;
    final dailyExceeded = isToday && projectedDaily > stats.dailyTarget;

    if (monthlyExceeded || dailyExceeded) {
      final diffMonthly = projectedMonthly - stats.monthlyTarget;
      final diffDaily = projectedDaily - stats.dailyTarget;

      String message = '';
      if (monthlyExceeded && dailyExceeded) {
        message = 'This exceeds your monthly target by ${currency.format(diffMonthly)} and daily target by ${currency.format(diffDaily)}.';
      } else if (monthlyExceeded) {
        message = 'This exceeds your monthly target by ${currency.format(diffMonthly)}.';
      } else {
        message = 'This exceeds your daily target by ${currency.format(diffDaily)}.';
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.expenseColor),
              SizedBox(width: 8),
              Text('Limit Warning', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text('$message\n\nDo you want to add this expense anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expenseColor),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ADD ANYWAY', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        NotificationService().showBudgetExceededNotification(
          title: 'Target Limit Exceeded',
          body: message,
        );
        return true; // isOverLimit = true
      } else {
        return false; // user cancelled addition
      }
    }
    return false; // Not over limit
  }

  Future<void> _addPresetEntry(Preset preset, double amount) async {
    final stats = ref.read(expenseStatsProvider);
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;
    final projectedMonthly = stats.monthTotal + amount;
    final projectedDaily = isToday ? stats.todayTotal + amount : amount;
    final wouldExceed = _type == 'expense' &&
        (projectedMonthly > stats.monthlyTarget || (isToday && projectedDaily > stats.dailyTarget));

    bool isOverLimit = false;
    if (wouldExceed) {
      final confirmed = await _checkLimitAlert(amount);
      if (!confirmed && (projectedMonthly > stats.monthlyTarget || (isToday && projectedDaily > stats.dailyTarget))) {
        return; // User cancelled adding
      }
      isOverLimit = true;
    }

    final repository = ref.read(expenseRepositoryProvider);
    final id = await repository.addExpense(
      name: preset.name,
      category: preset.category,
      amount: amount,
      type: _type,
      date: _selectedDate,
      isOverLimit: isOverLimit,
    );

    setState(() {
      _sessionAddedItems.insert(
        0,
        _SessionItem(
          id: id,
          name: preset.name,
          category: preset.category,
          amount: amount,
          type: _type,
          time: DateFormat.jm().format(_selectedDate),
        ),
      );
    });
  }

  Future<void> _addOtherEntry() async {
    if (!_otherFormKey.currentState!.validate()) return;

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
    final wouldExceed = _type == 'expense' &&
        (projectedMonthly > stats.monthlyTarget || (isToday && projectedDaily > stats.dailyTarget));

    bool isOverLimit = false;
    if (wouldExceed) {
      final confirmed = await _checkLimitAlert(amount);
      if (!confirmed && (projectedMonthly > stats.monthlyTarget || (isToday && projectedDaily > stats.dailyTarget))) {
        return; // User cancelled adding
      }
      isOverLimit = true;
    }

    final repository = ref.read(expenseRepositoryProvider);
    final id = await repository.addExpense(
      name: name,
      category: category,
      amount: amount,
      type: _type,
      date: _selectedDate,
      isOverLimit: isOverLimit,
    );

    setState(() {
      _sessionAddedItems.insert(
        0,
        _SessionItem(
          id: id,
          name: name,
          category: category,
          amount: amount,
          type: _type,
          time: DateFormat.jm().format(_selectedDate),
        ),
      );
      _nameController.clear();
      _amountController.clear();
      _categoryController.text = 'General';
    });
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isExpense = _type == 'expense';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header with Expense / Income Toggle & Done Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
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

                // Explicit Done Button to close popup
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done', style: TextStyle(fontSize: 14)),
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

          // Main Scrollable Area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                    // Include all configured presets in Quick Add
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
                            onTap: () => _addPresetEntry(preset, preset.defaultAmount),
                            onLongPress: () => _showPresetAmountOverrideDialog(preset),
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
                            onPressed: _addOtherEntry,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Entry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Running Session Summary ("Added in this Session")
                if (_sessionAddedItems.isNotEmpty) ...[
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
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessionAddedItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                      itemBuilder: (context, index) {
                        final item = _sessionAddedItems[index];
                        final itemIsExpense = item.type == 'expense';
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  Text(
                                    item.time,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.expenseColor),
                                tooltip: 'Remove from session',
                                onPressed: () => _removeSessionItem(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
  final String time;

  _SessionItem({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.type,
    required this.time,
  });
}
