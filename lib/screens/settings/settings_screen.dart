import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/currency_selector_dialog.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _salaryController;
  late TextEditingController _dailyTargetController;
  late TextEditingController _monthlyTargetController;
  late TextEditingController _savingsTargetController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileNotifierProvider);
    _salaryController = TextEditingController(text: profile.monthlySalary.toStringAsFixed(0));
    _dailyTargetController = TextEditingController(text: profile.dailyExpenseTarget.toStringAsFixed(0));
    _monthlyTargetController = TextEditingController(text: profile.monthlyExpenseTarget.toStringAsFixed(0));
    _savingsTargetController = TextEditingController(text: profile.monthlySavingsTarget.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _dailyTargetController.dispose();
    _monthlyTargetController.dispose();
    _savingsTargetController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final salary = double.tryParse(_salaryController.text.trim());
    final dailyTarget = double.tryParse(_dailyTargetController.text.trim());
    final monthlyTarget = double.tryParse(_monthlyTargetController.text.trim());
    final savingsTarget = double.tryParse(_savingsTargetController.text.trim());

    await ref.read(profileNotifierProvider.notifier).updateTargets(
          salary: salary,
          dailyTarget: dailyTarget,
          monthlyTarget: monthlyTarget,
          savingsTarget: savingsTarget,
        );

    if (salary != null && salary > 0) {
      await ref.read(expenseRepositoryProvider).syncSalaryPreset(salary);
    }

    if (!mounted) return;
    AppToast.show(context, 'Settings updated successfully!');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out / lock the application?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.expenseColor),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(profileNotifierProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final profile = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Account Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryAccent.withValues(alpha: 0.2),

                      child: const Icon(Icons.person, size: 32, color: AppTheme.primaryAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.userEmail.isNotEmpty ? profile.userEmail : 'Local User',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Offline Storage Active',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Financial Target Configurations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Currency Selector Card
              ListTile(
                tileColor: AppTheme.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.border),
                ),
                leading: const Icon(Icons.currency_exchange, color: AppTheme.primaryAccent),
                title: const Text('Currency'),
                subtitle: Text('${currency.name} (${currency.symbol})'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => showCurrencySelector(context, ref),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _salaryController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly Salary / Preset Income',
                  prefixText: '${currency.symbol} ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dailyTargetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Daily Expense Target',
                  prefixText: '${currency.symbol} ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _monthlyTargetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly Expense Target',
                  prefixText: '${currency.symbol} ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _savingsTargetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monthly Savings Target',
                  prefixText: '${currency.symbol} ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: AppTheme.expenseColor),
                  label: const Text('LOGOUT', style: TextStyle(color: AppTheme.expenseColor, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.expenseColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
