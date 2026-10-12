import 'package:flutter/foundation.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../domain/repositories/order_repository.dart';

class OrderController extends ChangeNotifier {
  final OrderRepository repository;

  bool _isLoading = false;
  List<IndividualOrder> _orders = [];
  String _selectedFilter = 'all'; // all, debt, prepaid, cod, unassigned
  String _searchQuery = '';

  OrderController({required this.repository});

  bool get isLoading => _isLoading;
  List<IndividualOrder> get orders => _filteredOrders();
  String get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;

  List<IndividualOrder> _filteredOrders() {
    return _orders.where((order) {
      if (_selectedFilter == 'debt' && order.paymentStatus != AppConstants.paymentDebt) {
        return false;
      }
      if (_selectedFilter == 'prepaid' && order.paymentStatus != AppConstants.paymentPrepaid) {
        return false;
      }
      if (_selectedFilter == 'cod' && order.paymentStatus != AppConstants.paymentCod) {
        return false;
      }
      if (_selectedFilter == 'unassigned' && (order.shipmentId != null && order.shipmentId!.isNotEmpty)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_searchQuery.trim().isEmpty) {
        _orders = await repository.getAllOrders();
      } else {
        _orders = await repository.searchOrders(_searchQuery.trim());
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    loadOrders();
  }

  Future<void> saveOrder(IndividualOrder order, List<OrderItem> items) async {
    await repository.saveOrder(order, items);
    await loadOrders();
  }

  Future<void> updateOrder(IndividualOrder order, List<OrderItem> items) async {
    await repository.updateOrder(order, items);
    await loadOrders();
  }

  Future<void> deleteOrder(String id) async {
    await repository.deleteOrder(id);
    await loadOrders();
  }

  /// تسجيل دفعة أو سداد للطلب
  Future<void> recordPayment(String orderId, double newPaidAmount, String newStatus) async {
    await repository.updatePaymentStatus(orderId, newStatus, newPaidAmount);
    await loadOrders();
  }

  /// توليد نص فاتورة منسق لمشاركته عبر واتساب
  String generateWhatsAppInvoice(IndividualOrder order) {
    final currencyService = CurrencyService.instance;
    final currency = order.currency;
    final buffer = StringBuffer();

    buffer.writeln('invoice_greeting'.trParams({'name': order.customerName ?? 'customer_dear'.i18n()}));
    buffer.writeln('invoice_order_title'.trParams({'number': order.orderNumber}));
    buffer.writeln('--------------------------------');

    for (int i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final itemPrice = item.sellPrice != null
          ? currencyService.formatAmount(item.sellPrice!, currencyCode: item.currency)
          : 'order_pricing_pending'.i18n();
      buffer.writeln('invoice_item_line'.trParams({
        'idx': '${i + 1}',
        'name': item.name,
        'qty': '${item.quantity}',
        'price': itemPrice,
      }));
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('invoice_total_amount'.trParams({
      'amount': currencyService.formatAmount(order.totalSellPrice, currencyCode: currency),
    }));
    buffer.writeln('invoice_paid_amount'.trParams({
      'amount': currencyService.formatAmount(order.paidAmount, currencyCode: currency),
    }));
    buffer.writeln('invoice_remaining_amount'.trParams({
      'amount': currencyService.formatAmount(order.remainingDebt, currencyCode: currency),
    }));

    if (order.expectedDeliveryDate != null) {
      buffer.writeln('invoice_expected_delivery'.trParams({
        'date': '${order.expectedDeliveryDate!.year}/${order.expectedDeliveryDate!.month}/${order.expectedDeliveryDate!.day}',
      }));
    }

    buffer.writeln('\n${'invoice_thank_you'.i18n()}');
    return buffer.toString();
  }
}
