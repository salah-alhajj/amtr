import 'dart:math' as math;

/// نتيجة حساب تسعير الوصفة والمنتج
class PricingResult {
  final double batchTotalCost;
  final double unitCost;
  final double rawSellPrice;
  final double suggestedSellPrice;
  final double unitProfit;
  final int yieldCount;
  final double marginPercent;
  final String currency;

  const PricingResult({
    required this.batchTotalCost,
    required this.unitCost,
    required this.rawSellPrice,
    required this.suggestedSellPrice,
    required this.unitProfit,
    required this.yieldCount,
    required this.marginPercent,
    required this.currency,
  });
}

/// خدمة حساب تكلفة الوصفة وتسعير الوحدة مع التقريب الذكي حسب العملة
class PricingCalculatorService {
  const PricingCalculatorService();

  PricingResult calculate({
    required List<double> ingredientCosts,
    required int yieldCount,
    required double marginPercent,
    required String currency,
  }) {
    final safeYield = math.max(1, yieldCount);
    final safeMargin = marginPercent < 0 ? 0.0 : marginPercent;

    double batchTotalCost = 0.0;
    for (final cost in ingredientCosts) {
      if (cost > 0) {
        batchTotalCost += cost;
      }
    }

    final unitCost = batchTotalCost / safeYield;
    final rawSellPrice = unitCost * (1 + safeMargin / 100);
    final suggestedSellPrice = _roundForCurrency(rawSellPrice, currency);
    final unitProfit = suggestedSellPrice - unitCost;

    return PricingResult(
      batchTotalCost: batchTotalCost,
      unitCost: unitCost,
      rawSellPrice: rawSellPrice,
      suggestedSellPrice: suggestedSellPrice,
      unitProfit: unitProfit,
      yieldCount: safeYield,
      marginPercent: safeMargin,
      currency: currency,
    );
  }

  double _roundForCurrency(double price, String currency) {
    if (price <= 0) return 0.0;
    switch (currency.toUpperCase()) {
      case 'YER':
        return (price / 50.0).round() * 50.0;
      case 'SAR':
        return price.roundToDouble();
      case 'USD':
        return (price * 2.0).round() / 2.0;
      default:
        return price.roundToDouble();
    }
  }
}
