import '../../../../models/expense.dart';
import '../../../../models/product.dart';
import '../../../../models/raw_material.dart';
import '../../../../models/supplier.dart';
import '../../../../models/supplier_transaction.dart';
import '../../../manufacturing/data/repositories/raw_material_repository.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../data/repositories/supplier_ledger_repository.dart';
import '../repositories/supplier_repository.dart';

/// حزمة بيانات شاشة تفاصيل المورد
class SupplierWorkspaceData {
  final List<Product> products;
  final List<RawMaterial> materials;
  final List<Expense> expenses;
  final SupplierBalanceSummary balanceSummary;
  final List<SupplierTransaction> transactions;

  const SupplierWorkspaceData({
    required this.products,
    required this.materials,
    required this.expenses,
    required this.balanceSummary,
    required this.transactions,
  });
}

/// خيارات المخزون المتاحة لربط مشتريات المورد بالتزويد التلقائي
class SupplierStockOptions {
  final List<Product> products;
  final List<RawMaterial> materials;

  const SupplierStockOptions({
    required this.products,
    required this.materials,
  });
}

/// خدمة أعمال نقية لإدارة عمليات الموردين ودفاترهم وتزويد المخزون
class SupplierBusinessService {
  final SupplierRepository supplierRepo;
  final SupplierLedgerRepository ledgerRepo;
  final ProductRepository productRepo;
  final RawMaterialRepository materialRepo;

  const SupplierBusinessService({
    required this.supplierRepo,
    required this.ledgerRepo,
    required this.productRepo,
    required this.materialRepo,
  });

  Future<SupplierWorkspaceData> loadSupplierWorkspace(String supplierId) async {
    final results = await Future.wait([
      supplierRepo.getProductsBySupplier(supplierId),
      supplierRepo.getMaterialsBySupplier(supplierId),
      supplierRepo.getExpensesBySupplier(supplierId),
      ledgerRepo.getBalanceSummary(supplierId),
      ledgerRepo.getTransactions(supplierId),
    ]);

    return SupplierWorkspaceData(
      products: results[0] as List<Product>,
      materials: results[1] as List<RawMaterial>,
      expenses: results[2] as List<Expense>,
      balanceSummary: results[3] as SupplierBalanceSummary,
      transactions: results[4] as List<SupplierTransaction>,
    );
  }

  Future<void> recordTransaction(
    SupplierTransaction tx, {
    required String supplierName,
    String? stockItemType,
    String? stockItemId,
    double stockQuantity = 0.0,
  }) {
    return ledgerRepo.recordTransaction(
      tx,
      supplierName: supplierName,
      stockItemType: stockItemType,
      stockItemId: stockItemId,
      stockQuantity: stockQuantity,
    );
  }

  Future<void> deleteTransaction(String txId) {
    return ledgerRepo.deleteTransaction(txId);
  }

  Future<void> updateSupplier(Supplier supplier) {
    return supplierRepo.updateSupplier(supplier);
  }

  Future<void> deleteSupplier(String supplierId) {
    return supplierRepo.deleteSupplier(supplierId);
  }

  Future<SupplierStockOptions> loadStockOptions() async {
    final results = await Future.wait([
      productRepo.getActiveProducts(),
      materialRepo.getAll(),
    ]);
    return SupplierStockOptions(
      products: results[0] as List<Product>,
      materials: results[1] as List<RawMaterial>,
    );
  }
}
