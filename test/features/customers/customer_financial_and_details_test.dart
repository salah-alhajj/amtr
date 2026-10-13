import 'package:flutter_test/flutter_test.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/features/customers/domain/customer_financial_helper.dart';
import 'package:mosaed/models/customer.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';

void main() {
  late CurrencyService currencyService;

  setUp(() {
    currencyService = CurrencyService.instance;
  });

  group('CustomerFinancialHelper Tests', () {
    test('Calculates green (benefited), red (debts), blue (credit) correctly', () {
      final customer = Customer(id: 'c1', name: 'أحمد التاجر');

      // طلب 1: تكلفة 1000، بيع 1500، مدفوع 1000 => دين 500، ربح 500
      final order1 = IndividualOrder(
        id: 'o1',
        orderNumber: 'ORD-001',
        customerId: 'c1',
        currency: AppConstants.currencyYer,
        paidAmount: 1000.0,
        orderStatus: AppConstants.orderStatusPending,
        items: [
          OrderItem(
            id: 'i1',
            orderId: 'o1',
            name: 'بضاعة 1',
            quantity: 1,
            costPrice: 1000.0,
            sellPrice: 1500.0,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final summary = CustomerFinancialHelper.calculate(
        customer: customer,
        orders: [order1],
        currencyService: currencyService,
      );

      // أخضر: مستفاد (أرباح) = 500 (يظهر)
      expect(summary.showBenefited, isTrue);
      expect(summary.benefitedAmount, equals(500.0));

      // أحمر: مديونيات = 500 (يظهر)
      expect(summary.showDebt, isTrue);
      expect(summary.debtsOwed, equals(500.0));

      // أزرق: متبقي له = 0 (يختفي تماماً)
      expect(summary.showCredit, isFalse);
      expect(summary.creditBalance, equals(0.0));
    });

    test('Disappears green, red, and blue when values are zero', () {
      final customer = Customer(id: 'c2', name: 'سعيد المتوازن');

      // طلب تكلفة 2000، بيع 2000 (ربح صفر)، مدفوع 2000 (دين صفر، فائض صفر)
      final order = IndividualOrder(
        id: 'o2',
        orderNumber: 'ORD-002',
        customerId: 'c2',
        currency: AppConstants.currencyYer,
        paidAmount: 2000.0,
        orderStatus: AppConstants.orderStatusDelivered,
        items: [
          OrderItem(
            id: 'i2',
            orderId: 'o2',
            name: 'بضاعة 2',
            quantity: 1,
            costPrice: 2000.0,
            sellPrice: 2000.0,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final summary = CustomerFinancialHelper.calculate(
        customer: customer,
        orders: [order],
        currencyService: currencyService,
      );

      // الكل صفر => تختفي البطاقات الثلاث
      expect(summary.showBenefited, isFalse);
      expect(summary.showDebt, isFalse);
      expect(summary.showCredit, isFalse);
      expect(summary.isBalanced, isTrue);
    });

    test('Shows blue when customer overpays (credit balance in his favor)', () {
      final customer = Customer(id: 'c3', name: 'خالد الزائد');

      // بيع 1000، مدفوع 1500 => رصيد متبقي له لدينا 500
      final order = IndividualOrder(
        id: 'o3',
        orderNumber: 'ORD-003',
        customerId: 'c3',
        currency: AppConstants.currencyYer,
        paidAmount: 1500.0,
        orderStatus: AppConstants.orderStatusDelivered,
        items: [
          OrderItem(
            id: 'i3',
            orderId: 'o3',
            name: 'غرض',
            quantity: 1,
            costPrice: 800.0,
            sellPrice: 1000.0,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final summary = CustomerFinancialHelper.calculate(
        customer: customer,
        orders: [order],
        currencyService: currencyService,
      );

      // أزرق: رصيد متبقي له لدينا 500
      expect(summary.showCredit, isTrue);
      expect(summary.creditBalance, equals(500.0));
      // أحمر: دين صفر (يختفي)
      expect(summary.showDebt, isFalse);
      // أخضر: ربح 200 (يظهر)
      expect(summary.showBenefited, isTrue);
      expect(summary.benefitedAmount, equals(200.0));
    });

    test('Filters between all orders, completed orders, and pending orders', () {
      final customer = Customer(id: 'c4', name: 'محمد المقسم');

      final orderCompleted = IndividualOrder(
        id: 'oc',
        orderNumber: 'ORD-C',
        customerId: 'c4',
        orderStatus: AppConstants.orderStatusDelivered,
        currency: AppConstants.currencyYer,
        paidAmount: 1000.0,
        items: [
          OrderItem(
            id: 'ic',
            orderId: 'oc',
            name: 'مكتمل',
            quantity: 1,
            costPrice: 600.0,
            sellPrice: 1000.0,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final orderPending = IndividualOrder(
        id: 'op',
        orderNumber: 'ORD-P',
        customerId: 'c4',
        orderStatus: AppConstants.orderStatusPending,
        currency: AppConstants.currencyYer,
        paidAmount: 0.0,
        items: [
          OrderItem(
            id: 'ip',
            orderId: 'op',
            name: 'معلق',
            quantity: 1,
            costPrice: 2000.0,
            sellPrice: 3000.0,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final allSummary = CustomerFinancialHelper.calculate(
        customer: customer,
        orders: [orderCompleted, orderPending],
        currencyService: currencyService,
        filter: CustomerOrderFilter.all,
      );
      expect(allSummary.totalSales, equals(4000.0));
      expect(allSummary.debtsOwed, equals(3000.0));

      final completedSummary = CustomerFinancialHelper.calculate(
        customer: customer,
        orders: [orderCompleted, orderPending],
        currencyService: currencyService,
        filter: CustomerOrderFilter.completedOnly,
      );
      expect(completedSummary.totalSales, equals(1000.0));
      expect(completedSummary.debtsOwed, equals(0.0));

      final pendingSummary = CustomerFinancialHelper.calculate(
        customer: customer,
        orders: [orderCompleted, orderPending],
        currencyService: currencyService,
        filter: CustomerOrderFilter.pendingOnly,
      );
      expect(pendingSummary.totalSales, equals(3000.0));
      expect(pendingSummary.debtsOwed, equals(3000.0));
    });

    test('Serializes and parses manual financial override without polluting user notes', () {
      const originalUserNotes = 'عميل جملة ممتاز من سوق الملح بصنعاء';
      const override = CustomerFinancialOverride(
        manualDebt: 7500.0,
        manualCredit: 2000.0,
        manualProfit: 1500.0,
        isManualEnabled: true,
        manualNotes: 'تسوية رصيد سابق',
      );

      final encoded = CustomerFinancialHelper.encodeNotesWithOverride(originalUserNotes, override);
      expect(encoded, contains(originalUserNotes));

      final cleanNotes = CustomerFinancialHelper.cleanUserNotes(encoded);
      expect(cleanNotes, equals(originalUserNotes));

      final parsedOverride = CustomerFinancialHelper.parseOverride(encoded);
      expect(parsedOverride.isManualEnabled, isTrue);
      expect(parsedOverride.manualDebt, equals(7500.0));
      expect(parsedOverride.manualCredit, equals(2000.0));
      expect(parsedOverride.manualProfit, equals(1500.0));
      expect(parsedOverride.manualNotes, equals('تسوية رصيد سابق'));
    });

    test('CustomerListFilter correctly matches customer status (debt, creditor, pending, whatsapp, no-orders)', () {
      final customerWithDebt = Customer(id: 'c_debt', name: 'عميل مدين', phone: '777000111');
      final debtSummary = CustomerFinancialSummary(
        benefitedAmount: 100,
        debtsOwed: 500,
        creditBalance: 0,
        totalSales: 1500,
        totalCost: 1000,
        totalPaid: 1000,
        allOrdersCount: 2,
        completedOrdersCount: 1,
        pendingOrdersCount: 1,
        debtsCount: 1,
        activeCurrency: AppConstants.currencyYer,
        financialOverride: const CustomerFinancialOverride(),
        appliedFilter: CustomerOrderFilter.all,
      );

      final customerCreditor = Customer(id: 'c_cred', name: 'عميل دائن', whatsapp: '966500000000');
      final credSummary = CustomerFinancialSummary(
        benefitedAmount: 200,
        debtsOwed: 0,
        creditBalance: 300,
        totalSales: 1000,
        totalCost: 800,
        totalPaid: 1300,
        allOrdersCount: 1,
        completedOrdersCount: 1,
        pendingOrdersCount: 0,
        debtsCount: 0,
        activeCurrency: AppConstants.currencyYer,
        financialOverride: const CustomerFinancialOverride(),
        appliedFilter: CustomerOrderFilter.all,
      );

      final newCustomerNoOrders = Customer(id: 'c_new', name: 'عميل جديد بدون طلبات');

      // 1. فلتر الكل
      expect(CustomerFinancialHelper.matchesFilter(customer: customerWithDebt, summary: debtSummary, filter: CustomerListFilter.all), isTrue);
      expect(CustomerFinancialHelper.matchesFilter(customer: newCustomerNoOrders, summary: null, filter: CustomerListFilter.all), isTrue);

      // 2. فلتر عليهم ديون
      expect(CustomerFinancialHelper.matchesFilter(customer: customerWithDebt, summary: debtSummary, filter: CustomerListFilter.hasDebt), isTrue);
      expect(CustomerFinancialHelper.matchesFilter(customer: customerCreditor, summary: credSummary, filter: CustomerListFilter.hasDebt), isFalse);

      // 3. فلتر لهم رصيد (دائنين)
      expect(CustomerFinancialHelper.matchesFilter(customer: customerCreditor, summary: credSummary, filter: CustomerListFilter.isCreditor), isTrue);
      expect(CustomerFinancialHelper.matchesFilter(customer: customerWithDebt, summary: debtSummary, filter: CustomerListFilter.isCreditor), isFalse);

      // 4. فلتر طلبات معلقة
      expect(CustomerFinancialHelper.matchesFilter(customer: customerWithDebt, summary: debtSummary, filter: CustomerListFilter.hasPendingOrders), isTrue);
      expect(CustomerFinancialHelper.matchesFilter(customer: customerCreditor, summary: credSummary, filter: CustomerListFilter.hasPendingOrders), isFalse);

      // 5. فلتر بدون طلبات
      expect(CustomerFinancialHelper.matchesFilter(customer: newCustomerNoOrders, summary: null, filter: CustomerListFilter.noOrders), isTrue);
      expect(CustomerFinancialHelper.matchesFilter(customer: customerWithDebt, summary: debtSummary, filter: CustomerListFilter.noOrders), isFalse);

      // 6. فلتر متاح واتساب
      expect(CustomerFinancialHelper.matchesFilter(customer: customerCreditor, summary: credSummary, filter: CustomerListFilter.hasWhatsApp), isTrue);
      expect(CustomerFinancialHelper.matchesFilter(customer: customerWithDebt, summary: debtSummary, filter: CustomerListFilter.hasWhatsApp), isFalse);
    });

    test('Customer edit round-trip preserves manual override without polluting clean notes', () {
      const override = CustomerFinancialOverride(
        manualDebt: 5000.0,
        manualCredit: 1000.0,
        manualProfit: 2500.0,
        isManualEnabled: true,
        manualNotes: 'تسوية شهر أكتوبر',
      );

      final originalNotes = CustomerFinancialHelper.encodeNotesWithOverride(
        'عميل مميز في الشحن الجوي',
        override,
      );

      final customer = Customer(
        id: 'cust_override_test',
        name: 'سالم المتميز',
        phone: '771234567',
        notes: originalNotes,
      );

      // 1. التأكد من أن الملاحظات المعروضة للمستخدم خالية تماماً من أكواد JSON والتاغ
      final userFacingNotes = CustomerFinancialHelper.cleanUserNotes(customer.notes);
      expect(userFacingNotes, equals('عميل مميز في الشحن الجوي'));
      expect(userFacingNotes.contains('<!--MOSAED_FINANCIAL_OVERRIDE:'), isFalse);
      expect(userFacingNotes.contains('<!--AMTR_FINANCIAL_OVERRIDE:'), isFalse);

      // 2. محاكاة تعديل التاجر لملاحظات العميل في الواجهة
      const updatedUserNotes = 'عميل كبار الشخصيات VIP';

      // 3. الحفظ وإعادة الدمج يحافظ على التسوية المالية بكل دقة
      final extractedOverride = CustomerFinancialHelper.parseOverride(customer.notes);
      final reEncodedNotes = CustomerFinancialHelper.encodeNotesWithOverride(
        updatedUserNotes,
        extractedOverride,
      );

      final updatedCustomer = customer.copyWith(notes: reEncodedNotes);
      final finalOverride = CustomerFinancialHelper.parseOverride(updatedCustomer.notes);

      expect(finalOverride.isManualEnabled, isTrue);
      expect(finalOverride.manualDebt, equals(5000.0));
      expect(finalOverride.manualCredit, equals(1000.0));
      expect(finalOverride.manualProfit, equals(2500.0));
      expect(finalOverride.manualNotes, equals('تسوية شهر أكتوبر'));
      expect(CustomerFinancialHelper.cleanUserNotes(updatedCustomer.notes), equals('عميل كبار الشخصيات VIP'));
    });
  });
}
