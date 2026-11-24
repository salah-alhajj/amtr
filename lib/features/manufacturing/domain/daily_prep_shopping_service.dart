import 'dart:math' as math;
import '../../../core/constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/localization/localization.dart';
import '../../../core/services/currency_service.dart';
import '../../../models/product.dart';
import '../../../models/product_bundle_item.dart';
import '../../../models/product_ingredient.dart';
import '../../../models/raw_material.dart';
import '../../../models/supplier.dart';
import '../../orders/data/repositories/order_repository_impl.dart';

/// ملخص منتج مطلوب تجهيزه ضمن ورقة التجهيز اليومية
class PrepProductSummary {
  final String? productId;
  final String productName;
  final int totalQty;
  final int batchCount;
  final int awaitingDepositCount;
  final List<String> customerNotes;

  const PrepProductSummary({
    this.productId,
    required this.productName,
    required this.totalQty,
    required this.batchCount,
    this.awaitingDepositCount = 0,
    this.customerNotes = const [],
  });
}

/// سطر مادة خام مطلوبة ضمن قائمة المشتريات اليومية
class ShoppingMaterialLine {
  final String? materialId;
  final String name;
  final String unit;
  final double requiredQty;
  final double inStockQty;
  final double toBuyQty;
  final double estimatedCost;
  final String currency;
  final String? supplierId;
  final String supplierName;
  final String? supplierPhone;

  const ShoppingMaterialLine({
    this.materialId,
    required this.name,
    required this.unit,
    required this.requiredQty,
    required this.inStockQty,
    required this.toBuyQty,
    required this.estimatedCost,
    required this.currency,
    this.supplierId,
    required this.supplierName,
    this.supplierPhone,
  });
}

/// خطة التجهيز اليومي وقائمة مشتريات الخامات المجمّعة حسب المورد
class DailyPrepPlan {
  final DateTime date;
  final List<PrepProductSummary> prepItems;
  final List<ShoppingMaterialLine> shoppingLines;
  final Map<String, List<ShoppingMaterialLine>> shoppingBySupplier;
  final double totalEstimatedCostYer;

  const DailyPrepPlan({
    required this.date,
    required this.prepItems,
    required this.shoppingLines,
    required this.shoppingBySupplier,
    required this.totalEstimatedCostYer,
  });
}

class _PrepAccumulator {
  final String? productId;
  final String productName;
  int totalQty = 0;
  int awaitingDepositCount = 0;
  final List<String> notes = [];
  final Set<String> _seenNotes = {};

  _PrepAccumulator({
    required this.productId,
    required this.productName,
  });

  void addNote(String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return;
    if (_seenNotes.add(trimmed)) {
      notes.add(trimmed);
    }
  }
}

class _MaterialAccumulator {
  final String? materialId;
  final String name;
  final String unit;
  final double fallbackUnitCost;
  final String fallbackCurrency;
  double requiredQty = 0.0;

  _MaterialAccumulator({
    this.materialId,
    required this.name,
    required this.unit,
    required this.fallbackUnitCost,
    required this.fallbackCurrency,
  });
}

/// محرك توليد ورقة التجهيز اليومية وقائمة مشتريات المواد الخام من الطلبات النشطة
class DailyPrepShoppingService {
  final AppDatabase dbHelper;
  final CurrencyService currencyService;

  DailyPrepShoppingService({
    AppDatabase? db,
    CurrencyService? currencyService,
  })  : dbHelper = db ?? AppDatabase.instance,
        currencyService = currencyService ?? CurrencyService.instance;

  /// بناء خطة التجهيز والمشتريات ليوم محدد
  Future<DailyPrepPlan> buildPlanForDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _buildPlanForRange(
      anchorDate: dayStart,
      startInclusive: dayStart,
      endExclusive: dayEnd,
    );
  }

  /// بناء خطة التجهيز والمشتريات لعدة أيام قادمة (افتراضياً اليوم وغداً)
  Future<DailyPrepPlan> buildPlanForUpcomingDays({
    int days = 2,
    DateTime? startDate,
  }) {
    final base = startDate ?? DateTime.now();
    final start = DateTime(base.year, base.month, base.day);
    final end = start.add(Duration(days: math.max(1, days)));
    return _buildPlanForRange(
      anchorDate: start,
      startInclusive: start,
      endExclusive: end,
    );
  }

  Future<DailyPrepPlan> _buildPlanForRange({
    required DateTime anchorDate,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final db = await dbHelper.database;
    final orderRepo = OrderRepositoryImpl(db: dbHelper);

    final results = await Future.wait([
      orderRepo.getAllOrders(),
      db.query('products'),
      db.query('product_ingredients'),
      db.query('raw_materials'),
      db.query('suppliers'),
      db.query('product_bundle_items'),
    ]);

    final allOrders = results[0] as List;
    final products = (results[1] as List<Map<String, dynamic>>)
        .map(Product.fromMap)
        .toList();
    final allIngredients = (results[2] as List<Map<String, dynamic>>)
        .map(ProductIngredient.fromMap)
        .toList();
    final materials = (results[3] as List<Map<String, dynamic>>)
        .map(RawMaterial.fromMap)
        .toList();
    final suppliers = (results[4] as List<Map<String, dynamic>>)
        .map(Supplier.fromMap)
        .toList();
    final allBundleItems = (results[5] as List<Map<String, dynamic>>)
        .map(ProductBundleItem.fromMap)
        .toList();

    final productsById = <String, Product>{
      for (final p in products) p.id: p,
    };
    final productsByLowerName = <String, Product>{
      for (final p in products) p.name.trim().toLowerCase(): p,
    };
    final ingredientsByProduct = <String, List<ProductIngredient>>{};
    for (final ing in allIngredients) {
      ingredientsByProduct.putIfAbsent(ing.productId, () => []).add(ing);
    }
    final bundleItemsByBundleId = <String, List<ProductBundleItem>>{};
    for (final bi in allBundleItems) {
      bundleItemsByBundleId.putIfAbsent(bi.bundleProductId, () => []).add(bi);
    }
    final materialsById = <String, RawMaterial>{
      for (final m in materials) m.id: m,
    };
    final suppliersById = <String, Supplier>{
      for (final s in suppliers) s.id: s,
    };

    // 1) تصفية الطلبات النشطة (غير المسلّمة) ضمن النطاق الزمني وتجميع المنتجات والملاحظات
    final prepAccByKey = <String, _PrepAccumulator>{};

    void recordPrepTarget({
      required String? targetProductId,
      required String targetProductName,
      required int qty,
      required bool isAwaitingDeposit,
      required String prefix,
      required String? itemDesc,
      required String? occasion,
      required String? orderNotes,
    }) {
      final key = targetProductId != null
          ? 'id:$targetProductId'
          : 'name:${targetProductName.toLowerCase()}';
      final acc = prepAccByKey.putIfAbsent(
        key,
        () => _PrepAccumulator(
          productId: targetProductId,
          productName: targetProductName,
        ),
      );
      acc.totalQty += qty;
      if (isAwaitingDeposit) {
        acc.awaitingDepositCount += 1;
      }
      if (itemDesc != null && itemDesc.trim().isNotEmpty) {
        acc.addNote('$prefix${itemDesc.trim()}');
      }
      if (occasion != null && occasion.trim().isNotEmpty) {
        acc.addNote('$prefix${occasion.trim()}');
      }
      if (orderNotes != null && orderNotes.trim().isNotEmpty) {
        acc.addNote('$prefix${orderNotes.trim()}');
      }
    }

    for (final dynamic order in allOrders) {
      if (order.orderStatus == AppConstants.orderStatusDelivered) continue;
      final DateTime effectiveDate =
          order.expectedDeliveryDate ?? order.createdAt;
      final effectiveDay = DateTime(
        effectiveDate.year,
        effectiveDate.month,
        effectiveDate.day,
      );
      if (effectiveDay.isBefore(startInclusive) ||
          !effectiveDay.isBefore(endExclusive)) {
        continue;
      }

      final String? customerName = order.customerName as String?;
      final String? orderNotes = order.notes as String?;
      final String? occasion = order.occasionLabel as String?;
      final bool isAwaitingDeposit = order.isAwaitingDeposit == true;

      for (final item in order.items) {
        final String? rawPid = item.productId as String?;
        final String itemName = (item.name as String).trim();
        final int orderItemQty = item.quantity as int;
        final Product? matchedProduct = (rawPid != null && rawPid.isNotEmpty)
            ? productsById[rawPid]
            : productsByLowerName[itemName.toLowerCase()];

        final prefix = (customerName != null && customerName.trim().isNotEmpty)
            ? '${customerName.trim()}: '
            : '';
        final itemDesc = item.description as String?;

        final bundleComponents =
            (matchedProduct != null && matchedProduct.isBundle)
                ? (bundleItemsByBundleId[matchedProduct.id] ?? const [])
                : const <ProductBundleItem>[];

        if (bundleComponents.isNotEmpty) {
          for (final bi in bundleComponents) {
            final compProduct = productsById[bi.componentProductId];
            final compId = compProduct?.id ?? bi.componentProductId;
            final compName = compProduct?.name ??
                (bi.componentName.trim().isNotEmpty
                    ? bi.componentName.trim()
                    : matchedProduct!.name);
            recordPrepTarget(
              targetProductId: compId,
              targetProductName: compName,
              qty: orderItemQty * math.max(1, bi.quantity),
              isAwaitingDeposit: isAwaitingDeposit,
              prefix: prefix,
              itemDesc: itemDesc,
              occasion: occasion,
              orderNotes: orderNotes,
            );
          }
        } else {
          final resolvedProductId = matchedProduct?.id ??
              ((rawPid != null && rawPid.isNotEmpty) ? rawPid : null);
          recordPrepTarget(
            targetProductId: resolvedProductId,
            targetProductName: matchedProduct?.name ?? itemName,
            qty: orderItemQty,
            isAwaitingDeposit: isAwaitingDeposit,
            prefix: prefix,
            itemDesc: itemDesc,
            occasion: occasion,
            orderNotes: orderNotes,
          );
        }
      }
    }

    // 2) بناء قائمة التجهيز وحساب متطلبات المواد الخام
    final prepItems = <PrepProductSummary>[];
    final materialAccByKey = <String, _MaterialAccumulator>{};

    for (final acc in prepAccByKey.values) {
      final product =
          acc.productId != null ? productsById[acc.productId!] : null;
      final batchYield = math.max(1, product?.batchYield ?? 1);
      final batchCount =
          acc.totalQty > 0 ? ((acc.totalQty + batchYield - 1) ~/ batchYield) : 0;

      prepItems.add(
        PrepProductSummary(
          productId: acc.productId,
          productName: acc.productName,
          totalQty: acc.totalQty,
          batchCount: batchCount,
          awaitingDepositCount: acc.awaitingDepositCount,
          customerNotes: List<String>.unmodifiable(acc.notes),
        ),
      );

      // حساب الخامات للمنتجات التي لها وصفة تصنيع
      if (product != null) {
        final recipeItems = ingredientsByProduct[product.id] ?? const [];
        if (recipeItems.isNotEmpty) {
          final factor = acc.totalQty / batchYield;
          for (final ing in recipeItems) {
            if (!ing.isMaterial) continue;
            final reqQty = factor * ing.quantity;
            if (reqQty <= 0) continue;

            final matId = (ing.materialId != null && ing.materialId!.isNotEmpty)
                ? ing.materialId
                : null;
            final rawMat = matId != null ? materialsById[matId] : null;
            final unit = rawMat?.unit ??
                (ing.unit != null && ing.unit!.trim().isNotEmpty
                    ? ing.unit!.trim()
                    : 'حبة');
            final matKey = matId != null
                ? 'mat:$matId'
                : 'custom:${ing.name.trim().toLowerCase()}|${unit.toLowerCase()}';

            final mAcc = materialAccByKey.putIfAbsent(
              matKey,
              () => _MaterialAccumulator(
                materialId: matId,
                name: rawMat?.name ?? ing.name,
                unit: unit,
                fallbackUnitCost: ing.unitCost > 0
                    ? ing.unitCost
                    : (ing.quantity > 0 ? ing.cost / ing.quantity : ing.cost),
                fallbackCurrency: ing.currency,
              ),
            );
            mAcc.requiredQty += reqQty;
          }
        }
      }
    }

    prepItems.sort((a, b) => b.totalQty.compareTo(a.totalQty));

    // 3) بناء سطور قائمة المشتريات وطرح المخزون الحالي وتجميعها حسب المورد
    final unassignedLabel = 'prep_unassigned_supplier'.i18n();
    final shoppingLines = <ShoppingMaterialLine>[];
    double totalEstimatedCostYer = 0.0;

    for (final mAcc in materialAccByKey.values) {
      final rawMat =
          mAcc.materialId != null ? materialsById[mAcc.materialId!] : null;
      final inStock = rawMat?.stockQuantity ?? 0.0;
      final toBuy = math.max(0.0, mAcc.requiredQty - inStock);
      final unitCost = rawMat?.unitCost ?? mAcc.fallbackUnitCost;
      final currency = rawMat?.currency ?? mAcc.fallbackCurrency;
      final estCost = toBuy * unitCost;
      final supplierId = rawMat?.supplierId;
      final supplier = supplierId != null ? suppliersById[supplierId] : null;
      final supplierName = supplier?.name ?? unassignedLabel;
      final supplierPhone = (supplier?.whatsapp != null &&
              supplier!.whatsapp!.trim().isNotEmpty)
          ? supplier.whatsapp
          : supplier?.phone;

      shoppingLines.add(
        ShoppingMaterialLine(
          materialId: mAcc.materialId,
          name: mAcc.name,
          unit: mAcc.unit,
          requiredQty: mAcc.requiredQty,
          inStockQty: inStock,
          toBuyQty: toBuy,
          estimatedCost: estCost,
          currency: currency,
          supplierId: supplierId,
          supplierName: supplierName,
          supplierPhone: supplierPhone,
        ),
      );
      totalEstimatedCostYer += currencyService.toBaseYer(estCost, currency);
    }

    shoppingLines.sort((a, b) {
      final aHasBuy = a.toBuyQty > 0;
      final bHasBuy = b.toBuyQty > 0;
      if (aHasBuy != bHasBuy) return aHasBuy ? -1 : 1;
      return b.estimatedCost.compareTo(a.estimatedCost);
    });

    final groupedRaw = <String, List<ShoppingMaterialLine>>{};
    for (final line in shoppingLines) {
      groupedRaw.putIfAbsent(line.supplierName, () => []).add(line);
    }

    final sortedKeys = groupedRaw.keys.toList()
      ..sort((a, b) {
        if (a == unassignedLabel && b != unassignedLabel) return 1;
        if (b == unassignedLabel && a != unassignedLabel) return -1;
        return a.compareTo(b);
      });

    final shoppingBySupplier = <String, List<ShoppingMaterialLine>>{
      for (final k in sortedKeys) k: groupedRaw[k]!,
    };

    return DailyPrepPlan(
      date: anchorDate,
      prepItems: prepItems,
      shoppingLines: shoppingLines,
      shoppingBySupplier: shoppingBySupplier,
      totalEstimatedCostYer: totalEstimatedCostYer,
    );
  }
}
