import '../../../../models/customer.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../../../models/product.dart';
import '../../../../models/product_variant.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../products/data/product_variant_repository.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../repositories/order_repository.dart';

/// حزمة البيانات الأولية لورقة البيع السريع
class QuickOrderBootstrapData {
  final List<Product> products;
  final List<Customer> customers;
  final Map<String, List<ProductVariant>> activeVariantsByProduct;
  final List<IndividualOrder> existingOrders;

  const QuickOrderBootstrapData({
    required this.products,
    required this.customers,
    required this.activeVariantsByProduct,
    required this.existingOrders,
  });
}

/// خدمة أعمال نقية لإدارة عمليات الطلبات والتحصيل بدون أي اعتماد على واجهة المستخدم أو قاعدة البيانات المباشرة
class OrderBusinessService {
  final OrderRepository orderRepo;
  final ProductRepository productRepo;
  final CustomerRepository customerRepo;
  final ProductVariantRepository variantRepo;

  const OrderBusinessService({
    required this.orderRepo,
    required this.productRepo,
    required this.customerRepo,
    required this.variantRepo,
  });

  Future<QuickOrderBootstrapData> loadQuickOrderData() async {
    final results = await Future.wait([
      productRepo.getActiveProducts(),
      customerRepo.getAllCustomers(),
      variantRepo.getAllGroupedByProduct(),
      orderRepo.getAllOrders(),
    ]);

    final groupedVariants = results[2] as Map<String, List<ProductVariant>>;
    final activeVariants = <String, List<ProductVariant>>{};
    for (final entry in groupedVariants.entries) {
      final active = entry.value.where((v) => v.isActive).toList();
      if (active.isNotEmpty) {
        activeVariants[entry.key] = active;
      }
    }

    return QuickOrderBootstrapData(
      products: results[0] as List<Product>,
      customers: results[1] as List<Customer>,
      activeVariantsByProduct: activeVariants,
      existingOrders: results[3] as List<IndividualOrder>,
    );
  }

  /// حساب صافي إجمالي البيع بدقة
  static double calculateNetTotal({
    required double itemsTotal,
    required double deliveryFee,
    required double discount,
  }) {
    final net = itemsTotal + deliveryFee - discount;
    return net > 0 ? net : 0.0;
  }

  Future<void> saveQuickOrder(
    IndividualOrder order,
    List<OrderItem> items,
  ) async {
    await orderRepo.saveOrder(order, items);
  }

  /// جلب كافة الطلبات ذات المديونية المفتوحة مرتبة من الأعلى مديونية
  Future<List<IndividualOrder>> loadUnpaidOrdersForCollection({
    required String returnedCourierStatus,
  }) async {
    final all = await orderRepo.getAllOrders();
    final unpaid = all
        .where(
          (o) =>
              o.remainingDebt > 0.01 &&
              o.courierStatus != returnedCourierStatus,
        )
        .toList()
      ..sort((a, b) => b.remainingDebt.compareTo(a.remainingDebt));
    return unpaid;
  }

  /// تسجيل دفعة سداد لطلب محدد مع تحديث حالة السداد
  Future<void> collectOrderPayment({
    required IndividualOrder order,
    required double amountPaid,
    required String newStatus,
  }) async {
    final newTotalPaid = order.paidAmount + amountPaid;
    await orderRepo.updatePaymentStatus(order.id, newStatus, newTotalPaid);
  }

  Future<Customer?> getCustomerById(String customerId) {
    return customerRepo.getCustomerById(customerId);
  }
}
