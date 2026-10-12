import 'package:flutter_test/flutter_test.dart';
import 'package:amtr/core/constants.dart';
import 'package:amtr/models/individual_order.dart';
import 'package:amtr/models/order_item.dart';

void main() {
  group('Debt Due Date & Alarm Reminder Suite Tests', () {
    final fixedDueDate = DateTime(2026, 10, 25, 16, 30);

    test('IndividualOrder stores debtDueDate, hasDebtReminder and isSyncedWithCalendar', () {
      final order = IndividualOrder(
        id: 'ord_debt_001',
        orderNumber: '8821',
        customerName: 'فهد التاجر',
        paymentStatus: AppConstants.paymentDebt,
        debtDueDate: fixedDueDate,
        hasDebtReminder: true,
        isSyncedWithCalendar: false,
        paidAmount: 50.0,
        currency: AppConstants.currencySar,
        items: [
          OrderItem(
            id: 'item_1',
            orderId: 'ord_debt_001',
            name: 'سماعات بلوتوث برو',
            quantity: 2,
            costPrice: 80.0,
            sellPrice: 120.0,
          ),
        ],
      );

      expect(order.debtDueDate, fixedDueDate);
      expect(order.hasDebtReminder, isTrue);
      expect(order.isSyncedWithCalendar, isFalse);
      expect(order.totalSellPrice, 240.0);
      expect(order.remainingDebt, 190.0);
    });

    test('Serialization toMap and fromMap preserves exact date, time, and flags', () {
      final original = IndividualOrder(
        id: 'ord_debt_002',
        orderNumber: '9902',
        customerName: 'سعيد عبد الله',
        paymentStatus: AppConstants.paymentDebt,
        debtDueDate: fixedDueDate,
        hasDebtReminder: true,
        isSyncedWithCalendar: true,
        paidAmount: 0.0,
        currency: AppConstants.currencyYer,
      );

      final map = original.toMap();
      expect(map['debtDueDate'], fixedDueDate.toIso8601String());
      expect(map['hasDebtReminder'], 1);
      expect(map['isSyncedWithCalendar'], 1);

      final restored = IndividualOrder.fromMap(map);
      expect(restored.debtDueDate, fixedDueDate);
      expect(restored.hasDebtReminder, isTrue);
      expect(restored.isSyncedWithCalendar, isTrue);
    });

    test('copyWith properly updates debtDueDate and reminder flags', () {
      final order = IndividualOrder(
        id: 'ord_debt_003',
        orderNumber: '9903',
        paymentStatus: AppConstants.paymentDebt,
      );

      expect(order.debtDueDate, isNull);
      expect(order.hasDebtReminder, isFalse);
      expect(order.isSyncedWithCalendar, isFalse);

      final updated = order.copyWith(
        debtDueDate: fixedDueDate,
        hasDebtReminder: true,
        isSyncedWithCalendar: true,
      );

      expect(updated.debtDueDate, fixedDueDate);
      expect(updated.hasDebtReminder, isTrue);
      expect(updated.isSyncedWithCalendar, isTrue);
    });
  });
}
