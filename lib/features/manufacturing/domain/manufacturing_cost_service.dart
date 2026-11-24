import 'dart:math' as math;
import '../../products/domain/pricing_calculator_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/data_sync_bus.dart';
import '../../../models/manufacturing_template.dart';
import '../../../models/product.dart';
import '../../../models/product_ingredient.dart';
import '../../../models/raw_material.dart';

/// أثر تغيّر سعر مادة خام على منتج مصنّع (التكلفة والهامش والسعر المقترح)
class MaterialPriceImpact {
  final Product product;
  final double oldCost;
  final double newCost;
  final double oldMarginPercent;
  final double newMarginPercent;
  final double suggestedSellPrice;
  final bool isMarginEroded;

  const MaterialPriceImpact({
    required this.product,
    required this.oldCost,
    required this.newCost,
    required this.oldMarginPercent,
    required this.newMarginPercent,
    required this.suggestedSellPrice,
    required this.isMarginEroded,
  });
}

/// خدمة تتبّع أثر تغيّر أسعار المواد الخام على قوالب التصنيع والمنتجات المصنّعة
class ManufacturingCostService {
  final AppDatabase dbHelper;
  final CurrencyService currencyService;
  final PricingCalculatorService pricingCalculator;

  ManufacturingCostService({
    AppDatabase? db,
    CurrencyService? currencyService,
    PricingCalculatorService? pricingCalculator,
  })  : dbHelper = db ?? AppDatabase.instance,
        currencyService = currencyService ?? CurrencyService.instance,
        pricingCalculator =
            pricingCalculator ?? const PricingCalculatorService();

  /// تحديث تكلفة المادة الخام في جميع القوالب والوصفات المرتبطة بها وإعادة حساب
  /// تكلفة كل منتج مصنّع متأثر، مع كشف حالات تآكل هامش الربح واقتراح سعر جديد.
  Future<List<MaterialPriceImpact>> recalculateOnMaterialPriceChange(
    RawMaterial updatedMaterial,
  ) async {
    final db = await dbHelper.database;
    final impacts = <MaterialPriceImpact>[];
    bool anyProductUpdated = false;

    await db.transaction((txn) async {
      // 1) تحديث بنود قوالب التصنيع المرتبطة بهذه المادة
      final templateRows = await txn.query(
        'manufacturing_template_items',
        where: 'materialId = ?',
        whereArgs: [updatedMaterial.id],
      );
      for (final row in templateRows) {
        final item = ManufacturingTemplateItem.fromMap(row);
        final convertedUnitCost = currencyService.convert(
          amount: updatedMaterial.unitCost,
          fromCurrency: updatedMaterial.currency,
          toCurrency: item.currency,
        );
        await txn.update(
          'manufacturing_template_items',
          {'unitCost': convertedUnitCost},
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }

      // 2) تحديث مكونات وصفات المنتجات المرتبطة بهذه المادة وجمع المنتجات المتأثرة
      final ingredientRows = await txn.query(
        'product_ingredients',
        where: 'materialId = ?',
        whereArgs: [updatedMaterial.id],
      );
      final affectedProductIds = <String>{};
      for (final row in ingredientRows) {
        final ing = ProductIngredient.fromMap(row);
        affectedProductIds.add(ing.productId);
        final convertedUnitCost = currencyService.convert(
          amount: updatedMaterial.unitCost,
          fromCurrency: updatedMaterial.currency,
          toCurrency: ing.currency,
        );
        final newLineCost = ing.quantity * convertedUnitCost;
        await txn.update(
          'product_ingredients',
          {
            'unitCost': convertedUnitCost,
            'cost': newLineCost,
          },
          where: 'id = ?',
          whereArgs: [ing.id],
        );
      }

      // 3) إعادة حساب costPrice لكل منتج مصنّع متأثر
      for (final productId in affectedProductIds) {
        final prodRows = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (prodRows.isEmpty) continue;
        final product = Product.fromMap(prodRows.first);
        if (!product.isManufactured) continue;

        final allIngRows = await txn.query(
          'product_ingredients',
          where: 'productId = ?',
          whereArgs: [productId],
        );
        final allIngredients =
            allIngRows.map(ProductIngredient.fromMap).toList();
        if (allIngredients.isEmpty) continue;

        double batchTotalInProductCurrency = 0.0;
        for (final ing in allIngredients) {
          final effCost = ing.effectiveCost;
          if (effCost <= 0) continue;
          batchTotalInProductCurrency += currencyService.convert(
            amount: effCost,
            fromCurrency: ing.currency,
            toCurrency: product.currency,
          );
        }

        final safeYield = math.max(1, product.batchYield);
        final oldCost = product.costPrice;
        final newCost = batchTotalInProductCurrency / safeYield;

        await txn.update(
          'products',
          {'costPrice': newCost},
          where: 'id = ?',
          whereArgs: [product.id],
        );
        anyProductUpdated = true;

        final oldMarginPercent = product.sellPrice > 0
            ? ((product.sellPrice - oldCost) / product.sellPrice) * 100.0
            : 0.0;
        final newMarginPercent = product.sellPrice > 0
            ? ((product.sellPrice - newCost) / product.sellPrice) * 100.0
            : 0.0;

        final marginDrop = oldMarginPercent - newMarginPercent;
        final isMarginEroded = product.sellPrice > 0 &&
            (newMarginPercent < 20.0 || marginDrop >= 5.0);

        // حساب نسبة الربح (Markup) المستهدفة لاقتراح سعر بيع يحافظ على الهامش
        double targetMarkupPercent = 35.0;
        if (oldCost > 0 && product.sellPrice > oldCost) {
          final prevMarkup = ((product.sellPrice - oldCost) / oldCost) * 100.0;
          if (prevMarkup >= 25.0) {
            targetMarkupPercent = prevMarkup.clamp(25.0, 300.0);
          }
        }

        final pricing = pricingCalculator.calculate(
          ingredientCosts: [batchTotalInProductCurrency],
          yieldCount: safeYield,
          marginPercent: targetMarkupPercent,
          currency: product.currency,
        );

        impacts.add(
          MaterialPriceImpact(
            product: product.copyWith(costPrice: newCost),
            oldCost: oldCost,
            newCost: newCost,
            oldMarginPercent: oldMarginPercent,
            newMarginPercent: newMarginPercent,
            suggestedSellPrice: pricing.suggestedSellPrice,
            isMarginEroded: isMarginEroded,
          ),
        );
      }
    });

    DataSyncBus.instance.notify(DataDomain.materials);
    if (anyProductUpdated) {
      DataSyncBus.instance.notify(DataDomain.products);
    }

    impacts.sort((a, b) {
      if (a.isMarginEroded != b.isMarginEroded) {
        return a.isMarginEroded ? -1 : 1;
      }
      return a.newMarginPercent.compareTo(b.newMarginPercent);
    });
    return impacts;
  }
}
