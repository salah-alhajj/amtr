import '../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/dashboard/domain/services/dashboard_operations_service.dart';
import '../../features/expenses/data/repositories/expense_repository_impl.dart';
import '../../features/expenses/domain/repositories/expense_repository.dart';
import '../../features/manufacturing/data/repositories/production_batch_repository.dart';
import '../../features/manufacturing/data/repositories/raw_material_repository.dart';
import '../../features/orders/data/repositories/order_repository_impl.dart';
import '../../features/orders/domain/repositories/order_repository.dart';
import '../../features/orders/domain/services/order_business_service.dart';
import '../../features/products/data/product_variant_repository.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/domain/services/product_catalog_service.dart';
import '../../features/shipments/data/repositories/shipment_repository_impl.dart';
import '../../features/shipments/domain/repositories/shipment_repository.dart';
import '../../features/suppliers/data/repositories/supplier_ledger_repository.dart';
import '../../features/suppliers/data/repositories/supplier_repository_impl.dart';
import '../../features/suppliers/domain/repositories/supplier_repository.dart';
import '../../features/suppliers/domain/services/supplier_business_service.dart';
import '../audit/audit.dart';

/// موفر الاعتماديات والخدمات المركزية لعزل طبقة العرض عن تفاصيل التخزين والمنطق
class AppServices {
  AppServices._();

  static AppServices instance = AppServices._();

  static void reset() {
    instance = AppServices._();
  }

  late final OrderRepository orderRepository = OrderRepositoryImpl();
  late final ShipmentRepository shipmentRepository = ShipmentRepositoryImpl();
  late final CustomerRepository customerRepository = CustomerRepositoryImpl();
  late final ProductRepository productRepository = ProductRepositoryImpl();
  late final ExpenseRepository expenseRepository = ExpenseRepositoryImpl();
  late final SupplierRepository supplierRepository = SupplierRepositoryImpl();
  late final SupplierLedgerRepository supplierLedgerRepository =
      SupplierLedgerRepository();
  late final ProductVariantRepository productVariantRepository =
      ProductVariantRepository();
  late final ProductionBatchRepository productionBatchRepository =
      ProductionBatchRepository();
  late final RawMaterialRepository rawMaterialRepository =
      RawMaterialRepository();

  CentralAuditService get auditService => CentralAuditService.instance;
  AuditRepository get auditRepository => CentralAuditService.instance.repository;

  late final OrderBusinessService orderService = OrderBusinessService(
    orderRepo: orderRepository,
    productRepo: productRepository,
    customerRepo: customerRepository,
    variantRepo: productVariantRepository,
  );

  late final ProductCatalogService productCatalogService = ProductCatalogService(
    supplierRepo: supplierRepository,
    variantRepo: productVariantRepository,
    batchRepo: productionBatchRepository,
  );

  late final SupplierBusinessService supplierService = SupplierBusinessService(
    supplierRepo: supplierRepository,
    ledgerRepo: supplierLedgerRepository,
    productRepo: productRepository,
    materialRepo: rawMaterialRepository,
  );

  late final DashboardOperationsService dashboardService =
      DashboardOperationsService(
        orderRepository: orderRepository,
        shipmentRepository: shipmentRepository,
        customerRepository: customerRepository,
        expenseRepository: expenseRepository,
      );
}
