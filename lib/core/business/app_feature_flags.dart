/// أعلام إظهار/إخفاء الميزات المتقدمة حسب دور المستخدم أو تخصيصه اليدوي
class AppFeatureFlags {
  final bool shipments;
  final bool manufacturing;
  final bool dailyPrep;
  final bool curingWaste;
  final bool suppliers;
  final bool couriers;
  final bool variantsBundles;
  final bool seasonalDeposit;

  const AppFeatureFlags({
    this.shipments = false,
    this.manufacturing = true,
    this.dailyPrep = true,
    this.curingWaste = true,
    this.suppliers = true,
    this.couriers = true,
    this.variantsBundles = true,
    this.seasonalDeposit = true,
  });

  static const String keyShipments = 'shipments';
  static const String keyManufacturing = 'manufacturing';
  static const String keyDailyPrep = 'dailyPrep';
  static const String keyCuringWaste = 'curingWaste';
  static const String keySuppliers = 'suppliers';
  static const String keyCouriers = 'couriers';
  static const String keyVariantsBundles = 'variantsBundles';
  static const String keySeasonalDeposit = 'seasonalDeposit';

  static const List<String> allKeys = [
    keyShipments,
    keyManufacturing,
    keyDailyPrep,
    keyCuringWaste,
    keySuppliers,
    keyCouriers,
    keyVariantsBundles,
    keySeasonalDeposit,
  ];

  /// القيم الافتراضية المناسبة لكل دور/نمط عمل لتقليل الزحمة والتعقيد
  factory AppFeatureFlags.defaultsForMode(String mode) {
    switch (mode) {
      case 'simple_home_seller':
        return const AppFeatureFlags(
          shipments: false,
          manufacturing: false,
          dailyPrep: false,
          curingWaste: false,
          suppliers: false,
          couriers: false,
          variantsBundles: false,
          seasonalDeposit: false,
        );
      case 'artisan_craft':
        return const AppFeatureFlags(
          shipments: false,
          manufacturing: true,
          dailyPrep: false,
          curingWaste: true,
          suppliers: true,
          couriers: true,
          variantsBundles: true,
          seasonalDeposit: true,
        );
      case 'retail_shop':
        return const AppFeatureFlags(
          shipments: false,
          manufacturing: false,
          dailyPrep: false,
          curingWaste: false,
          suppliers: true,
          couriers: true,
          variantsBundles: true,
          seasonalDeposit: false,
        );
      case 'trade_logistics':
        return const AppFeatureFlags(
          shipments: true,
          manufacturing: false,
          dailyPrep: false,
          curingWaste: false,
          suppliers: true,
          couriers: true,
          variantsBundles: false,
          seasonalDeposit: false,
        );
      case 'productive_family':
      default:
        return const AppFeatureFlags(
          shipments: false,
          manufacturing: true,
          dailyPrep: true,
          curingWaste: true,
          suppliers: true,
          couriers: true,
          variantsBundles: true,
          seasonalDeposit: true,
        );
    }
  }

  bool isEnabled(String key) {
    switch (key) {
      case keyShipments:
        return shipments;
      case keyManufacturing:
        return manufacturing;
      case keyDailyPrep:
        return dailyPrep;
      case keyCuringWaste:
        return curingWaste;
      case keySuppliers:
        return suppliers;
      case keyCouriers:
        return couriers;
      case keyVariantsBundles:
        return variantsBundles;
      case keySeasonalDeposit:
        return seasonalDeposit;
      default:
        return false;
    }
  }

  int get enabledCount {
    var count = 0;
    for (final k in allKeys) {
      if (isEnabled(k)) count++;
    }
    return count;
  }

  AppFeatureFlags copyWith({
    bool? shipments,
    bool? manufacturing,
    bool? dailyPrep,
    bool? curingWaste,
    bool? suppliers,
    bool? couriers,
    bool? variantsBundles,
    bool? seasonalDeposit,
  }) {
    return AppFeatureFlags(
      shipments: shipments ?? this.shipments,
      manufacturing: manufacturing ?? this.manufacturing,
      dailyPrep: dailyPrep ?? this.dailyPrep,
      curingWaste: curingWaste ?? this.curingWaste,
      suppliers: suppliers ?? this.suppliers,
      couriers: couriers ?? this.couriers,
      variantsBundles: variantsBundles ?? this.variantsBundles,
      seasonalDeposit: seasonalDeposit ?? this.seasonalDeposit,
    );
  }

  AppFeatureFlags withOverride(String key, bool value) {
    switch (key) {
      case keyShipments:
        return copyWith(shipments: value);
      case keyManufacturing:
        return copyWith(manufacturing: value);
      case keyDailyPrep:
        return copyWith(dailyPrep: value);
      case keyCuringWaste:
        return copyWith(curingWaste: value);
      case keySuppliers:
        return copyWith(suppliers: value);
      case keyCouriers:
        return copyWith(couriers: value);
      case keyVariantsBundles:
        return copyWith(variantsBundles: value);
      case keySeasonalDeposit:
        return copyWith(seasonalDeposit: value);
      default:
        return this;
    }
  }

  Map<String, bool> toJsonMap() => {
        keyShipments: shipments,
        keyManufacturing: manufacturing,
        keyDailyPrep: dailyPrep,
        keyCuringWaste: curingWaste,
        keySuppliers: suppliers,
        keyCouriers: couriers,
        keyVariantsBundles: variantsBundles,
        keySeasonalDeposit: seasonalDeposit,
      };

  AppFeatureFlags applyOverrides(Map<String, dynamic> overrides) {
    var result = this;
    for (final entry in overrides.entries) {
      if (entry.value is bool) {
        result = result.withOverride(entry.key, entry.value as bool);
      }
    }
    return result;
  }
}
