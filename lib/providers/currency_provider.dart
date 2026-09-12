import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  String format(double amount) {
    final formatter = NumberFormat.currency(symbol: '$symbol ', decimalDigits: 2);
    return formatter.format(amount);
  }
}

const List<Currency> availableCurrencies = [
  Currency(code: 'USD', symbol: '\$', name: 'US Dollar (USD)'),
  Currency(code: 'BDT', symbol: '৳', name: 'Bangladeshi Taka (BDT)'),
  Currency(code: 'EUR', symbol: '€', name: 'Euro (EUR)'),
  Currency(code: 'GBP', symbol: '£', name: 'British Pound (GBP)'),
  Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee (INR)'),
  Currency(code: 'CAD', symbol: 'CA\$', name: 'Canadian Dollar (CAD)'),
  Currency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar (AUD)'),
  Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen (JPY)'),
  Currency(code: 'SAR', symbol: '﷼', name: 'Saudi Riyal (SAR)'),
  Currency(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham (AED)'),
];

class CurrencyNotifier extends StateNotifier<Currency> {
  CurrencyNotifier() : super(availableCurrencies.first) {
    _loadSavedCurrency();
  }

  static const String _key = 'selected_currency_code';

  Future<void> _loadSavedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_key);
    if (savedCode != null) {
      final found = availableCurrencies.firstWhere(
        (c) => c.code == savedCode,
        orElse: () => availableCurrencies.first,
      );
      state = found;
    }
  }

  Future<void> setCurrency(Currency currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, currency.code);
  }
}

final currencyProvider = StateNotifierProvider<CurrencyNotifier, Currency>((ref) {
  return CurrencyNotifier();
});
