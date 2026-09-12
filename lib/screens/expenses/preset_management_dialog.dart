import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';

class PresetManagementScreen extends ConsumerWidget {
  const PresetManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(presetsStreamProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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
                  subtitle: Text(
                    preset.category,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencyFormatter.format(preset.defaultAmount),
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
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPresetFormDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showPresetFormDialog(BuildContext context, WidgetRef ref, {Preset? preset}) {
    final nameController = TextEditingController(text: preset?.name ?? '');
    final categoryController = TextEditingController(text: preset?.category ?? 'General');
    final amountController = TextEditingController(
      text: preset != null ? preset.defaultAmount.toStringAsFixed(2) : '',
    );
    String selectedType = preset?.type ?? 'expense';
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
                        decoration: const InputDecoration(
                          labelText: 'Default Amount',
                          prefixText: '\$ ',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) return 'Invalid amount';
                          return null;
                        },
                      ),
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
                      final amount = double.parse(amountController.text.trim());

                      if (preset == null) {
                        await ref.read(expenseRepositoryProvider).addPreset(
                              name: name,
                              category: category,
                              defaultAmount: amount,
                              type: selectedType,
                            );
                      } else {
                        await ref.read(expenseRepositoryProvider).updatePreset(
                              preset.copyWith(
                                name: name,
                                category: category,
                                defaultAmount: amount,
                                type: selectedType,
                              ),
                            );
                      }
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
