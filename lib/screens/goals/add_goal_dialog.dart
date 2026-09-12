import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/currency_provider.dart';
import '../../providers/goal_provider.dart';

class AddGoalDialog extends ConsumerStatefulWidget {
  final String? initialName;

  const AddGoalDialog({super.key, this.initialName});

  static Future<void> show(BuildContext context, {String? initialName}) {
    return showDialog(
      context: context,
      builder: (_) => AddGoalDialog(initialName: initialName),
    );
  }

  @override
  ConsumerState<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends ConsumerState<AddGoalDialog> {
  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _noteController;
  DateTime? _targetDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _costController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = ref.watch(currencyProvider).symbol;

    return AlertDialog(
      title: const Text('New Goal / Wishlist'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: widget.initialName == null || widget.initialName!.isEmpty,
                decoration: const InputDecoration(
                  labelText: 'Goal Name *',
                  hintText: 'e.g. Save for Laptop, Vacation',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a goal name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Target Cost (Optional)',
                  prefixText: '$currencySymbol ',
                  hintText: '0.00',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final sanitized = v.trim().replaceAll(',', '.');
                  final p = double.tryParse(sanitized);
                  if (p == null || p < 0) return 'Enter valid target cost';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note / Description (Optional)',
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Target Date (Optional)', style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                    _targetDate != null
                        ? DateFormat('yyyy-MM-dd').format(_targetDate!)
                        : 'No target date set',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_targetDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => setState(() => _targetDate = null),
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined, size: 20),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setState(() => _targetDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 44)),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final name = _nameController.text.trim();
              final costText = _costController.text.trim();
              final noteText = _noteController.text.trim();
              final sanitizedCost = costText.replaceAll(',', '.');
              final targetCostVal = sanitizedCost.isNotEmpty ? double.tryParse(sanitizedCost) : null;

              await ref.read(goalRepositoryProvider).addGoal(
                    name: name,
                    targetCost: targetCostVal,
                    note: noteText.isNotEmpty ? noteText : null,
                    targetDate: _targetDate,
                  );

              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Added goal "$name"'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          child: const Text('Add Goal'),
        ),
      ],
    );
  }
}
