import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';

class PresetManagementScreen extends ConsumerWidget {
  const PresetManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(presetsStreamProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Regular Presets'),
      ),
      body: presetsAsync.when(
        data: (presets) {
          if (presets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark_border, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    const Text(
                      'No Presets Configured',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add regular expenses (like Coffee, Bus Fare, Lunch) to quickly log them with one tap.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showPresetFormDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Preset'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: presets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final preset = presets[index];
              return Card(
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Row(
                      children: [
                        Text(
                          preset.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: preset.type == 'income'
                                ? AppTheme.incomeColor.withValues(alpha: 0.15)
                                : AppTheme.expenseColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            preset.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: preset.type == 'income'
                                  ? AppTheme.incomeColor
                                  : AppTheme.expenseColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                            ),
                            child: Text(
                              preset.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (preset.isAutoAdd)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.autorenew, size: 12, color: AppTheme.primaryAccent),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Auto: ${_formatDayString(preset.autoAddDay)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primaryAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currency.format(preset.defaultAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: preset.type == 'income'
                                ? AppTheme.incomeColor
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showPresetFormDialog(context, ref, preset: preset),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.expenseColor),
                          onPressed: () {
                            ref.read(expenseRepositoryProvider).deletePreset(preset.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'preset_management_fab',
        onPressed: () => _showPresetFormDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDayString(int day) {
    if (day == 1) return '1st of month';
    if (day == 2) return '2nd of month';
    if (day == 3) return '3rd of month';
    if (day >= 21 && day % 10 == 1) return '${day}st of month';
    if (day >= 22 && day % 10 == 2) return '${day}nd of month';
    if (day >= 23 && day % 10 == 3) return '${day}rd of month';
    return '${day}th of month';
  }

  void _showPresetFormDialog(BuildContext context, WidgetRef ref, {Preset? preset}) {
    final nameController = TextEditingController(text: preset?.name ?? '');
    final categoryController = TextEditingController(text: preset?.category ?? 'General');
    final amountController = TextEditingController(
      text: preset != null ? preset.defaultAmount.toStringAsFixed(2) : '',
    );
    String selectedType = preset?.type ?? 'expense';
    bool isAutoAdd = preset?.isAutoAdd ?? false;
    int autoAddDay = preset?.autoAddDay ?? 1;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(preset == null ? 'New Preset' : 'Edit Preset'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'expense',
                            label: Text('Expense'),
                            icon: Icon(Icons.arrow_downward, size: 16),
                          ),
                          ButtonSegment(
                            value: 'income',
                            label: Text('Income'),
                            icon: Icon(Icons.arrow_upward, size: 16),
                          ),
                        ],
                        selected: {selectedType},
                        onSelectionChanged: (newSelection) {
                          setDialogState(() {
                            selectedType = newSelection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Preset Name',
                          hintText: 'e.g. Coffee, Salary',
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter a name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'e.g. Food, Salary, Transport',
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter category' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Default Amount',
                          prefixText: '${ref.read(currencyProvider).symbol} ',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          final sanitized = val.trim().replaceAll(',', '.');
                          final parsed = double.tryParse(sanitized);
                          if (parsed == null || parsed < 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Automatic Add Every Month',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Auto-creates transaction on selected date of month',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: isAutoAdd,
                        activeTrackColor: AppTheme.primaryAccent,
                        onChanged: (val) {
                          setDialogState(() {
                            isAutoAdd = val;
                          });
                        },
                      ),
                      if (isAutoAdd) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Auto-Add Date:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: autoAddDay,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(31, (index) {
                                  final day = index + 1;
                                  return DropdownMenuItem<int>(
                                    value: day,
                                    child: Text(_formatDayString(day)),
                                  );
                                }),
                                onChanged: (newDay) {
                                  if (newDay != null) {
                                    setDialogState(() {
                                      autoAddDay = newDay;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(80, 44)),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final category = categoryController.text.trim();
                      final sanitized = amountController.text.trim().replaceAll(',', '.');
                      final amount = double.tryParse(sanitized) ?? 0.0;
                      final repo = ref.read(expenseRepositoryProvider);

                      if (preset == null) {
                        await repo.addPreset(
                          name: name,
                          category: category,
                          defaultAmount: amount,
                          type: selectedType,
                          isAutoAdd: isAutoAdd,
                          autoAddDay: autoAddDay,
                        );
                      } else {
                        await repo.updatePreset(
                          preset.copyWith(
                            name: name,
                            category: category,
                            defaultAmount: amount,
                            type: selectedType,
                            isAutoAdd: isAutoAdd,
                            autoAddDay: autoAddDay,
                          ),
                        );
                      }

                      await repo.processAutoAddPresets(DateTime.now());

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
