import '../../../../models/product.dart';
import '../../../../models/production_batch.dart';
import '../../../manufacturing/data/repositories/production_batch_repository.dart';
import '../../../suppliers/domain/repositories/supplier_repository.dart';
import '../../data/product_variant_repository.dart';

/// بيانات مساعدة لكتالوج المنتجات (أسماء الموردين + المنتجات ذات المتغيرات)
class CatalogMetadata {
  final Map<String, String> supplierNames;
  final Set<String> variantProductIds;

  const CatalogMetadata({
    required this.supplierNames,
    required this.variantProductIds,
  });
}

/// خدمة أعمال نقية لكتالوج المنتجات وإنتاج التشغيلات بدون ارتباط بطبقة الواجهة
class ProductCatalogService {
  const ProductCatalogService({
    required this.supplierRepo,
    required this.variantRepo,
    required this.batchRepo,
  });

  final SupplierRepository supplierRepo;
  final ProductVariantRepository variantRepo;
  final ProductionBatchRepository batchRepo;

  Future<CatalogMetadata> loadCatalogMetadata() async {
    final results = await Future.wait([
      supplierRepo.getAllSuppliers(),
      variantRepo.getActiveVariantProductIds(),
    ]);

    final suppliers = results[0] as List<dynamic>;
    final map = <String, String>{};
    for (final s in suppliers) {
      map[s.id as String] = s.name as String;
    }

    return CatalogMetadata(
      supplierNames: map,
      variantProductIds: results[1] as Set<String>,
    );
  }

  Future<Set<String>> loadVariantProductIds() {
    return variantRepo.getActiveVariantProductIds();
  }

  Future<Map<String, String>> loadSupplierNames() async {
    final list = await supplierRepo.getAllSuppliers();
    return {for (final s in list) s.id: s.name};
  }

  Future<ProductionBatch> produceBatch({
    required Product product,
    int? customYield,
    bool deductMaterials = true,
    bool logExpense = false,
    String? notes,
    int curingDays = 0,
    int shelfLifeDays = 0,
  }) {
    return batchRepo.produceBatch(
      product: product,
      customYield: customYield,
      deductMaterials: deductMaterials,
      logExpense: logExpense,
      notes: notes,
      curingDays: curingDays,
      shelfLifeDays: shelfLifeDays,
    );
  }
}
