import '../../../../models/expense.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../customers/domain/smart_reorder_service.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../shipments/domain/repositories/shipment_repository.dart';

/// خدمة أعمال نقية لعمليات لوحة التحكم اليومية والبحث وتنبيهات إعادة الطلب
class DashboardOperationsService {
  final OrderRepository orderRepository;
  final ShipmentRepository shipmentRepository;
  final CustomerRepository customerRepository;
  final ExpenseRepository expenseRepository;
  final SmartReorderService _reorderService;

  DashboardOperationsService({
    required this.orderRepository,
    required this.shipmentRepository,
    required this.customerRepository,
    required this.expenseRepository,
    SmartReorderService? reorderService,
  }) : _reorderService = reorderService ?? SmartReorderService();

  Future<void> recordQuickExpense(Expense expense) {
    return expenseRepository.createExpense(expense);
  }

  Future<List<SmartReorderNudge>> loadDueReorderNudges({int limit = 3}) {
    return _reorderService.getDueReorderNudges(limit: limit);
  }
}
