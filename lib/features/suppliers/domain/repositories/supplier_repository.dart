import '../../../../models/expense.dart';
import '../../../../models/product.dart';
import '../../../../models/raw_material.dart';
import '../../../../models/supplier.dart';

abstract class SupplierRepository {
  Future<List<Supplier>> getAllSuppliers();
  Future<Supplier?> getSupplierById(String id);
  Future<void> createSupplier(Supplier supplier);
  Future<void> updateSupplier(Supplier supplier);
  Future<void> deleteSupplier(String id);
  Future<Map<String, int>> getLinkedProductCounts();
  Future<List<Product>> getProductsBySupplier(String supplierId);
  Future<List<RawMaterial>> getMaterialsBySupplier(String supplierId);
  Future<List<Expense>> getExpensesBySupplier(String supplierId);
}
