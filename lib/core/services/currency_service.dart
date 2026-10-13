import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../database/app_database.dart';

/// خدمة الصرافة وتعدد العملات والتحويل الفوري
/// تعتمد الريال اليمني (YER) كعملة قاعدة، وتتيح ضبط أسعار صرف الريال السعودي (SAR) والدولار (USD).
class CurrencyService extends ChangeNotifier {
  static final CurrencyService instance = CurrencyService._init();

  CurrencyService._init();

  double _sarToYer = 535.0; // 1 ريال سعودي = 535 ريال يمني
  double _usdToYer = 2040.0; // 1 دولار أمريكي = 2040 ريال يمني
  String _activeDisplayCurrency =
      AppConstants.currencyYer; // العملة المختارة للعرض في الهوم

  double get sarToYer => _sarToYer;
  double get usdToYer => _usdToYer;
  String get activeDisplayCurrency => _activeDisplayCurrency;

  Future<void> init() async {
    final db = await AppDatabase.instance.database;
    final records = await db.query('exchange_rates', limit: 1);
    if (records.isNotEmpty) {
      _sarToYer = (records.first['sarToYer'] as num).toDouble();
      _usdToYer = (records.first['usdToYer'] as num).toDouble();
      notifyListeners();
    }
  }

  /// تغيير العملة المعروضة في الشاشات والإحصائيات
  void setDisplayCurrency(String currencyCode) {
    if (_activeDisplayCurrency != currencyCode) {
      _activeDisplayCurrency = currencyCode;
      notifyListeners();
    }
  }

  /// تحديث أسعار الصرف وحفظها في قاعدة البيانات المحلية
  Future<void> updateRates({
    required double newSarToYer,
    required double newUsdToYer,
  }) async {
    _sarToYer = newSarToYer;
    _usdToYer = newUsdToYer;

    final db = await AppDatabase.instance.database;
    await db.update(
      'exchange_rates',
      {
        'sarToYer': newSarToYer,
        'usdToYer': newUsdToYer,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: ['default_rates'],
    );

    notifyListeners();
  }

  /// تحويل أي مبلغ من أي عملة إلى العملة الأساسية (الريال اليمني)
  double toBaseYer(double amount, String fromCurrency) {
    switch (fromCurrency.toUpperCase()) {
      case AppConstants.currencySar:
        return amount * _sarToYer;
      case AppConstants.currencyUsd:
        return amount * _usdToYer;
      case AppConstants.currencyYer:
      default:
        return amount;
    }
  }

  /// تحويل مبلغ من العملة الأساسية (الريال اليمني) إلى عملة مستهدفة
  double fromBaseYer(double amountInYer, String targetCurrency) {
    switch (targetCurrency.toUpperCase()) {
      case AppConstants.currencySar:
        return _sarToYer > 0 ? (amountInYer / _sarToYer) : 0;
      case AppConstants.currencyUsd:
        return _usdToYer > 0 ? (amountInYer / _usdToYer) : 0;
      case AppConstants.currencyYer:
      default:
        return amountInYer;
    }
  }

  /// تحويل مباشر بين أي عملتين
  double convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) {
    if (fromCurrency == toCurrency) return amount;
    final amountInYer = toBaseYer(amount, fromCurrency);
    return fromBaseYer(amountInYer, toCurrency);
  }

  /// تنسيق المبلغ مع رمزه المعتمد رسمياً (مثل رمز الريال السعودي SAMA: \u{20C1})
  String formatAmount(
    double amount, {
    String? currencyCode,
    int decimalDigits = 2,
  }) {
    final currency = currencyCode ?? _activeDisplayCurrency;
    final symbol = AppConstants.getCurrencySymbol(currency);
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: (amount % 1 == 0) ? 0 : decimalDigits,
      customPattern: '#,##0.## \u00a4',
    );
    return formatter.format(amount).trim();
  }
}
