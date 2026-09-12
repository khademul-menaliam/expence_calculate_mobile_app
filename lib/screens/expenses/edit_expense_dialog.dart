import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';

class EditExpenseDialog extends ConsumerStatefulWidget {
  final Expense expense;

  const EditExpenseDialog({super.key, required this.expense});

  static Future<void> show(BuildContext context, Expense expense) {
    return showDialog(
      context: context,
      builder: (_) => EditExpenseDialog(expense: expense),
    );
  }

  @override
  ConsumerState<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends ConsumerState<EditExpenseDialog> {
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _amountController;
  late String _type;
  late DateTime _date;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense.name);
    _categoryController = TextEditingController(text: widget.expense.category);
    _amountController = TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
    _type = widget.expense.type;
    _date = widget.expense.date;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = ref.watch(currencyProvider).symbol;

    return AlertDialog(
      title: const Text('Edit Entry'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Segmented type selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (set) {
                  setState(() => _type = set.first);
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter category' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$currencySymbol ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null || parsed <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Date display & picker button
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date & Time', style: TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(_date)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined, size: 20),
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate == null || !context.mounted) return;
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_date),
                    );
                    if (pickedTime != null && mounted) {
                      setState(() {
                        _date = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.expenseColor),
          tooltip: 'Delete entry',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Entry?'),
                content: Text('Are you sure you want to delete "${widget.expense.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.expenseColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

            if (confirm == true && context.mounted) {
              final nav = Navigator.of(context);
              final repo = ref.read(expenseRepositoryProvider);
              final itemToDelete = widget.expense;
              await repo.deleteExpense(itemToDelete.id);
              nav.pop();

              final rootCtx = context;
              if (rootCtx.mounted) {
                ScaffoldMessenger.of(rootCtx).clearSnackBars();
                ScaffoldMessenger.of(rootCtx).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${itemToDelete.name}"'),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: Colors.amber,
                      onPressed: () async {
                        await repo.addExpense(
                          name: itemToDelete.name,
                          category: itemToDelete.category,
                          amount: itemToDelete.amount,
                          type: itemToDelete.type,
                          date: itemToDelete.date,
                        );
                      },
                    ),
                  ),
                );
              }
            }
          },
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 44)),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final nav = Navigator.of(context);
              final updated = widget.expense.copyWith(
                name: _nameController.text.trim(),
                category: _categoryController.text.trim(),
                amount: double.parse(_amountController.text.trim()),
                type: _type,
                date: _date,
              );
              await ref.read(expenseRepositoryProvider).updateExpense(updated);
              if (mounted) {
                nav.pop();
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
