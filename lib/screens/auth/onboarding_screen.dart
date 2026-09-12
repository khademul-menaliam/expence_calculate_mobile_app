import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/currency_selector_dialog.dart';
import '../main_navigation_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _salaryController = TextEditingController(text: '20000');
  final _dailyTargetController = TextEditingController(text: '500');
  final _monthlyTargetController = TextEditingController(text: '15000');
  final _savingsTargetController = TextEditingController(text: '5000');

  @override
  void dispose() {
    _pageController.dispose();
    _salaryController.dispose();
    _dailyTargetController.dispose();
    _monthlyTargetController.dispose();
    _savingsTargetController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final salary = double.tryParse(_salaryController.text.trim()) ?? 20000.0;
      final dailyTarget = double.tryParse(_dailyTargetController.text.trim()) ?? 500.0;
      final monthlyTarget = double.tryParse(_monthlyTargetController.text.trim()) ?? 15000.0;
      final savingsTarget = double.tryParse(_savingsTargetController.text.trim()) ?? 5000.0;

      // Save profile preferences
      await ref.read(profileNotifierProvider.notifier).saveOnboardingProfile(
            salary: salary,
            dailyTarget: dailyTarget,
            monthlyTarget: monthlyTarget,
            savingsTarget: savingsTarget,
          );

      // Ensure pinned monthly salary entry is created in database
      try {
        final repository = ref.read(expenseRepositoryProvider);
        await repository.ensureMonthlySalaryPinned(salary, DateTime.now());
      } catch (_) {}

      if (!mounted) return;
      AppToast.show(context, 'Profile setup complete! Welcome.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Setup saved with defaults.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Setup Your Financial Profile'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _finishOnboarding,
            child: const Text('SKIP', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [

            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentPage + 1) / 4,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  // Step 1: Currency & Income
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Currency & Monthly Salary',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set your preferred currency and base monthly salary.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          title: const Text('Select Currency'),
                          subtitle: Text('${currency.name} (${currency.symbol})'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => showCurrencySelector(context, ref),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _salaryController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monthly Salary / Income Preset',
                            prefixText: '${currency.symbol} ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Step 2: Daily & Monthly Expense Targets
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Expense Budget Limits',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set your maximum daily and monthly expense targets to receive over-budget warnings.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _dailyTargetController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Daily Expense Target',
                            prefixText: '${currency.symbol} ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _monthlyTargetController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monthly Expense Target',
                            prefixText: '${currency.symbol} ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Step 3: Savings Target
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '3. Monthly Savings Goal',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'How much do you aim to save each month?',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _savingsTargetController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monthly Savings Target',
                            prefixText: '${currency.symbol} ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Step 4: Summary & Confirm
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '4. Confirm & Start Tracking',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Review your profile settings before proceeding to the main dashboard.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            children: [
                              _ProfileRow(label: 'Currency', value: '${currency.symbol} (${currency.code})'),
                              const Divider(),
                              _ProfileRow(label: 'Monthly Salary', value: '${currency.symbol}${_salaryController.text}'),
                              const Divider(),
                              _ProfileRow(label: 'Daily Target', value: '${currency.symbol}${_dailyTargetController.text}'),
                              const Divider(),
                              _ProfileRow(label: 'Monthly Target', value: '${currency.symbol}${_monthlyTargetController.text}'),
                              const Divider(),
                              _ProfileRow(label: 'Monthly Savings', value: '${currency.symbol}${_savingsTargetController.text}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('BACK'),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentPage == 3 ? 'FINISH' : 'NEXT',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
