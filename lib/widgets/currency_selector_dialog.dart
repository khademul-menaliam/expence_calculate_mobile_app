import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/currency_provider.dart';
import '../theme/app_theme.dart';

void showCurrencySelector(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final selectedCurrency = ref.watch(currencyProvider);

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.currency_exchange, color: AppTheme.primaryAccent),
                      SizedBox(width: 8),
                      Text(
                        'Select App Currency',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppTheme.border),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: availableCurrencies.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (context, index) {
                      final curr = availableCurrencies[index];
                      final isSelected = curr.code == selectedCurrency.code;

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryAccent.withValues(alpha: 0.15)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: AppTheme.primaryAccent, width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              curr.symbol,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? AppTheme.primaryAccent
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          title: Text(
                            curr.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: AppTheme.primaryAccent)
                              : null,
                          onTap: () {
                            ref.read(currencyProvider.notifier).setCurrency(curr);
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
