import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/utils/yemen_phone_helper.dart';
import 'package:mosaed/features/cashbox/data/repositories/daily_closing_repository.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/products/data/product_ingredient_repository.dart';
import 'package:mosaed/features/products/domain/pricing_calculator_service.dart';
import 'package:mosaed/features/whatsapp/domain/whatsapp_template_engine.dart';
import 'package:mosaed/models/daily_closing.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';
import 'package:mosaed/models/product_ingredient.dart';
import 'package:mosaed/models/whatsapp_template.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    await PreferencesService.instance.setBusinessMode(
      AppConstants.businessModeProductiveFamily,
    );
    await PreferencesService.instance.setBusinessName('مطبخ أم محمد');
    await PreferencesService.instance.setBusinessPhone('771234567');

    LocalizationHelper.setStrings({
      'cat_food_sweets': 'مأكولات وحلويات',
      'cat_perfume_bakhoor': 'بخور وعطور',
      'yer': 'ر.ي',
    }, 'ar');

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 7,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
  });

  tearDown(() async {
    await db.delete('whatsapp_templates');
    await db.delete('product_ingredients');
    await db.delete('daily_closings');
    await db.delete('payment_transactions');
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('products');
  });

  group('Phase 2 (W2.1): OrdersBloc Prep Queue & Undo Tests', () {
    test('Filters today, new, preparing, ready, occasions and supports Advance + Revert Undo', () async {
      final repo = OrderRepositoryImpl();
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      await repo.saveOrder(
        IndividualOrder(
          id: 'o_new_today',
          orderNumber: 'P2-1',
          orderStatus: AppConstants.orderStatusPending,
          expectedDeliveryDate: now,
          occasionLabel: 'عزيمة عائلية',
          currency: AppConstants.currencyYer,
        ),
        [],
      );
      await repo.saveOrder(
        IndividualOrder(
          id: 'o_prep',
          orderNumber: 'P2-2',
          orderStatus: AppConstants.orderStatusPurchased,
          createdAt: now.subtract(const Duration(days: 2)),
          expectedDeliveryDate: tomorrow,
          currency: AppConstants.currencyYer,
        ),
        [],
      );
      await repo.saveOrder(
        IndividualOrder(
          id: 'o_ready',
          orderNumber: 'P2-3',
          orderStatus: AppConstants.orderStatusReady,
          expectedDeliveryDate: now,
          currency: AppConstants.currencyYer,
        ),
        [],
      );

      final bloc = OrdersBloc(repository: repo);
      bloc.add(const LoadOrders());
      await expectLater(bloc.stream, emitsThrough(isA<OrdersLoaded>()));

      bloc.add(const FilterOrders('today'));
      await pumpEventQueue();
      expect((bloc.state as OrdersLoaded).displayedOrders.length, 2);

      bloc.add(const FilterOrders('new'));
      await pumpEventQueue();
      expect((bloc.state as OrdersLoaded).displayedOrders.length, 1);
      expect((bloc.state as OrdersLoaded).displayedOrders.first.id, 'o_new_today');

      bloc.add(const FilterOrders('preparing'));
      await pumpEventQueue();
      expect((bloc.state as OrdersLoaded).displayedOrders.length, 1);

      bloc.add(const FilterOrders('ready'));
      await pumpEventQueue();
      expect((bloc.state as OrdersLoaded).displayedOrders.length, 1);

      bloc.add(const FilterOrders('occasions'));
      await pumpEventQueue();
      expect((bloc.state as OrdersLoaded).displayedOrders.any((o) => o.id == 'o_new_today'), isTrue);

      // Advance then Revert (Undo)
      bloc.add(const AdvanceOrderStatusEvent('o_new_today', AppConstants.orderStatusPurchased));
      await pumpEventQueue();
      final afterAdvance = await repo.getOrderById('o_new_today');
      expect(afterAdvance!.orderStatus, AppConstants.orderStatusPurchased);

      bloc.add(const RevertOrderStatusEvent('o_new_today', AppConstants.orderStatusPending));
      await pumpEventQueue();
      final afterRevert = await repo.getOrderById('o_new_today');
      expect(afterRevert!.orderStatus, AppConstants.orderStatusPending);

      await bloc.close();
    });
  });

  group('Phase 2 (W2.2): WhatsApp Templates & Gulf Phone Helper Tests', () {
    test('WhatsAppTemplateEngine renders all 4 types and warm reminder omits harsh debt word', () {
      final order = IndividualOrder(
        id: 'o_wa',
        orderNumber: 'WA-77',
        customerName: 'سارة',
        paidAmount: 2000,
        currency: AppConstants.currencySar,
        items: [
          OrderItem(
            id: 'oi_wa',
            orderId: 'o_wa',
            name: 'بسبوسة بالقشطة',
            quantity: 2,
            costPrice: 50,
            sellPrice: 2500,
            currency: AppConstants.currencySar,
          ),
        ],
      );

      final confirmMsg = WhatsAppTemplateEngine.renderOrderMessage(
        order: order,
        type: 'confirm_deposit',
      );
      expect(confirmMsg, contains('سارة'));
      expect(confirmMsg, contains('WA-77'));
      expect(confirmMsg, contains('مطبخ أم محمد'));

      final readyMsg = WhatsAppTemplateEngine.renderOrderMessage(
        order: order,
        type: 'ready',
      );
      expect(readyMsg, contains('جاهز'));

      final warmReminder = WhatsAppTemplateEngine.renderOrderMessage(
        order: order,
        type: 'reminder',
        tone: 'warm',
      );
      expect(warmReminder.contains('دين'), isFalse);
      expect(warmReminder, contains('سارة'));

      final thanksMsg = WhatsAppTemplateEngine.renderOrderMessage(
        order: order,
        type: 'thanks',
      );
      expect(thanksMsg, contains('سارة'));
    });

    test('buildCategorizedCatalogText groups active products without duplicate header', () {
      final text = WhatsAppTemplateEngine.buildCategorizedCatalogText([
        Product(id: 'p1', name: 'كنافة', category: 'cat_food_sweets', unit: 'صينية', sellPrice: 4000),
        Product(id: 'p2', name: 'مبخرة', category: 'cat_perfume_bakhoor', unit: 'حبة', sellPrice: 2500),
        Product(id: 'p3', name: 'مخفي', category: 'cat_food_sweets', sellPrice: 1000, isActive: false),
      ]);
      expect(text, contains('مأكولات وحلويات'));
      expect(text, contains('بخور وعطور'));
      expect(text, contains('كنافة'));
      expect(text, isNot(contains('مخفي')));
    });

    test('YemenPhoneHelper supports Gulf country codes alongside Yemen', () {
      expect(YemenPhoneHelper.cleanForWhatsApp('+971501234567'), '971501234567');
      expect(YemenPhoneHelper.cleanForWhatsApp('0096551234567'), '96551234567');
      expect(YemenPhoneHelper.isValid('+971501234567'), isTrue);
      expect(YemenPhoneHelper.isValid('+97433123456'), isTrue);
      expect(YemenPhoneHelper.isValid('+96891234567'), isTrue);
      expect(YemenPhoneHelper.isValid('+97333123456'), isTrue);
      expect(YemenPhoneHelper.cleanForWhatsApp('771234567'), '967771234567');
    });
  });

  group('Phase 2 (W2.3): Pricing Calculator, Daily Closing & v7 Backup Tests', () {
    test('PricingCalculatorService calculates unit cost, margin and smart rounding', () {
      const calc = PricingCalculatorService();
      final yerRes = calc.calculate(
        ingredientCosts: [3000, 1500, 500], // 5000 total
        yieldCount: 10, // 500 per unit
        marginPercent: 50, // raw 750
        currency: AppConstants.currencyYer,
      );
      expect(yerRes.batchTotalCost, 5000);
      expect(yerRes.unitCost, 500);
      expect(yerRes.suggestedSellPrice, 750);
      expect(yerRes.unitProfit, 250);

      final sarRes = calc.calculate(
        ingredientCosts: [100],
        yieldCount: 3, // 33.33
        marginPercent: 50, // raw 50.0
        currency: AppConstants.currencySar,
      );
      expect(sarRes.suggestedSellPrice, 50);
    });

    test('ProductIngredientRepository, DailyClosingRepository and v7 JSON backup round-trip', () async {
      final ingRepo = ProductIngredientRepository();
      await ingRepo.replaceForProduct('prod_x', [
        const ProductIngredient(id: 'i1', productId: 'prod_x', name: 'دقيق', cost: 1200, yieldCount: 12),
      ]);
      final fetchedIng = await ingRepo.getByProductId('prod_x');
      expect(fetchedIng.length, 1);

      final closingRepo = DailyClosingRepository();
      await closingRepo.saveClosing(DailyClosing(
        id: 'dc_1',
        closingDate: '2026-11-24',
        cashInYer: 15000,
        businessExpensesYer: 3000,
        personalDrawingsYer: 2000,
        ordersCount: 4,
      ));
      final closing = await closingRepo.getClosingForDate(DateTime(2026, 11, 24));
      expect(closing, isNotNull);
      expect(closing!.netDrawerYer, 10000);

      await db.insert(
        'whatsapp_templates',
        const WhatsAppTemplate(
          id: 'tpl_custom',
          type: 'ready',
          tone: 'warm',
          title: 'جاهز مخصص',
          body: 'طلبك جاهز يا {customer}',
        ).toMap(),
      );

      final json = await AppDatabase.instance.exportAllDataToJson();
      expect((json['product_ingredients'] as List).length, 1);
      expect((json['daily_closings'] as List).length, 1);
      expect((json['whatsapp_templates'] as List).length, 1);

      await db.delete('product_ingredients');
      await db.delete('daily_closings');
      await db.delete('whatsapp_templates');

      await AppDatabase.instance.importAllDataFromJson(json);
      expect((await ingRepo.getByProductId('prod_x')).length, 1);
      expect((await closingRepo.getRecentClosings()).length, 1);
    });
  });
}
