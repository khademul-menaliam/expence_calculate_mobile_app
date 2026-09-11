import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/goal_provider.dart';

class EditGoalDialog extends ConsumerStatefulWidget {
  final Goal goal;

  const EditGoalDialog({super.key, required this.goal});

  static Future<void> show(BuildContext context, Goal goal) {
    return showDialog(
      context: context,
      builder: (_) => EditGoalDialog(goal: goal),
    );
  }

  @override
  ConsumerState<EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends ConsumerState<EditGoalDialog> {
  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _noteController;
  DateTime? _targetDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _costController = TextEditingController(
      text: widget.goal.targetCost != null ? widget.goal.targetCost!.toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: widget.goal.note ?? '');
    _targetDate = widget.goal.targetDate;
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
    return AlertDialog(
      title: const Text('Edit Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Goal Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a goal name' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Target Cost (Optional)',
                  prefixText: '\$ ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final p = double.tryParse(v.trim());
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

              ListTile(
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
              final costText = _costController.text.trim();
              final noteText = _noteController.text.trim();

              final updated = widget.goal.copyWith(
                name: _nameController.text.trim(),
                targetCost: Value(costText.isNotEmpty ? double.parse(costText) : null),
                note: Value(noteText.isNotEmpty ? noteText : null),
                targetDate: Value(_targetDate),
              );

              await ref.read(goalRepositoryProvider).updateGoal(updated);
              if (mounted) {
                navigator.pop();
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
