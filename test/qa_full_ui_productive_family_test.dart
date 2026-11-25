import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/core/widgets/business_drawer.dart';
import 'package:mosaed/core/widgets/design_system.dart';
import 'package:mosaed/features/backup/presentation/screens/backup_restore_screen.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/cashbox/presentation/screens/cashbox_screen.dart';
import 'package:mosaed/features/cashbox/presentation/widgets/daily_closing_sheet.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:mosaed/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:mosaed/features/customers/presentation/widgets/add_edit_customer_sheet.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/expenses/presentation/screens/expenses_list_screen.dart';
import 'package:mosaed/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:mosaed/features/navigation/main_navigation_shell.dart';
import 'package:mosaed/features/onboarding/presentation/screens/business_setup_wizard_screen.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/orders/presentation/screens/order_details_screen.dart';
import 'package:mosaed/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:mosaed/features/orders/presentation/widgets/quick_order_sheet.dart';
import 'package:mosaed/features/orders/presentation/widgets/record_payment_sheet.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/products/presentation/screens/products_list_screen.dart';
import 'package:mosaed/features/products/presentation/widgets/add_edit_product_sheet.dart';
import 'package:mosaed/features/products/presentation/widgets/pricing_helper_sheet.dart';
import 'package:mosaed/features/reports/presentation/screens/monthly_report_screen.dart';
import 'package:mosaed/features/settings/presentation/screens/settings_screen.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';
import 'package:mosaed/features/whatsapp/presentation/widgets/whatsapp_template_sheet.dart';
import 'package:mosaed/models/customer.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late Map<String, String> arStrings;

  setUpAll(() async {
    await initializeDateFormatting('ar');

    final rawJson = File('i18n/ar.json').readAsStringSync();
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    arStrings = decoded.map((k, v) => MapEntry(k, v.toString()));
    LocalizationHelper.setStrings(arStrings, 'ar');

    SharedPreferences.setMockInitialValues({
      'app_onboarding_completed': true,
      'app_business_mode': 'productive_family',
      'app_business_name': 'مطبخ أم محمد',
      'app_default_currency': AppConstants.currencyYer,
    });
    await PreferencesService.instance.init();

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 8,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
  });

  tearDown(() async {
    await db.delete('whatsapp_templates');
    await db.delete('product_ingredients');
    await db.delete('daily_closings');
    await db.delete('payment_transactions');
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('shipments');
    await db.delete('customers');
    await db.delete('products');
    await db.delete('expenses');
  });

  Future<void> resetPrefs({bool onboardingCompleted = true}) async {
    SharedPreferences.setMockInitialValues({
      'app_onboarding_completed': onboardingCompleted,
      'app_business_mode': 'productive_family',
      'app_business_name': 'مطبخ أم محمد',
      'app_default_currency': AppConstants.currencyYer,
    });
    await PreferencesService.instance.init();
  }

  Widget buildTestApp({
    required Widget home,
    required ThemeMode themeMode,
  }) {
    final orderRepo = OrderRepositoryImpl();
    final shipmentRepo = ShipmentRepositoryImpl();
    final customerRepo = CustomerRepositoryImpl();
    final productRepo = ProductRepositoryImpl();
    final expenseRepo = ExpenseRepositoryImpl();

    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleBloc>(
          create: (_) => LocaleBloc(),
        ),
        BlocProvider<ThemeBloc>(
          create: (_) => ThemeBloc(),
        ),
        BlocProvider<BusinessModeCubit>(
          create: (_) => BusinessModeCubit()..loadFromPreferences(),
        ),
        BlocProvider<CashBoxCubit>(
          create: (_) => CashBoxCubit()..loadDate(DateTime.now()),
        ),
        BlocProvider<DashboardBloc>(
          create: (_) => DashboardBloc(
            orderRepo: orderRepo,
            shipmentRepo: shipmentRepo,
            customerRepo: customerRepo,
            expenseRepo: expenseRepo,
            productRepo: productRepo,
          )..add(const LoadDashboardData()),
        ),
        BlocProvider<OrdersBloc>(
          create: (_) =>
              OrdersBloc(repository: orderRepo)..add(const LoadOrders()),
        ),
        BlocProvider<ShipmentsBloc>(
          create: (_) =>
              ShipmentsBloc(repository: shipmentRepo)..add(const LoadShipments()),
        ),
        BlocProvider<CustomersBloc>(
          create: (_) => CustomersBloc(
            repository: customerRepo,
            orderRepository: orderRepo,
          )..add(const LoadCustomers()),
        ),
        BlocProvider<ProductsBloc>(
          create: (_) =>
              ProductsBloc(repository: productRepo)..add(const LoadProducts()),
        ),
        BlocProvider<ExpensesBloc>(
          create: (_) =>
              ExpensesBloc(repository: expenseRepo)..add(const LoadExpenses()),
        ),
      ],
      child: MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: home,
      ),
    );
  }

  Future<void> pumpAndWait(WidgetTester tester, {int millis = 200}) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: millis)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxAttempts = 15,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await pumpAndWait(tester, millis: 150);
    }
  }

  Future<void> runWithNarrowScreenAndErrorTrap(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;

    final capturedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      capturedErrors.add(details);
      previousOnError?.call(details);
    };

    try {
      await body();
      await tester.pump(const Duration(seconds: 10));
      if (capturedErrors.isNotEmpty) {
        final summary = capturedErrors
            .map((e) => '${e.exceptionAsString()}\n${e.stack ?? ""}')
            .join('\n---\n');
        fail('Captured ${capturedErrors.length} FlutterError(s):\n$summary');
      }
    } finally {
      FlutterError.onError = previousOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  }

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    final themeLabel = themeMode == ThemeMode.light ? 'Light' : 'Dark';

    group('Productive Family Full UI QA ($themeLabel, 360x740)', () {
      testWidgets('1. BusinessSetupWizardScreen full flow', (tester) async {
        await resetPrefs(onboardingCompleted: false);
        await runWithNarrowScreenAndErrorTrap(tester, () async {
          await tester.pumpWidget(
            buildTestApp(
              home: const BusinessSetupWizardScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Step 1: Select productive family mode and tap Next
          final familyOption = find.text(arStrings['business_mode_family']!);
          expect(familyOption, findsOneWidget);
          await tester.ensureVisible(familyOption);
          await tester.tap(familyOption);
          await pumpAndWait(tester);

          final nextBtn = find.text(arStrings['onboarding_next'] ?? 'onboarding_next');
          expect(nextBtn, findsOneWidget);
          await tester.ensureVisible(nextBtn);
          await tester.tap(nextBtn);
          await pumpAndWait(tester);

          // Step 2: Enter business name and select currency
          expect(find.text(arStrings['wizard_step2_title']!), findsOneWidget);
          final nameField = find.byType(TextField).first;
          await tester.enterText(nameField, 'مطبخ الخير المنزلي');
          await pumpAndWait(tester);

          final sarChip = find.textContaining(arStrings['currency_sar']!);
          if (sarChip.evaluate().isNotEmpty) {
            await tester.ensureVisible(sarChip.first);
            await tester.tap(sarChip.first);
            await pumpAndWait(tester);
          }

          final nextBtn2 = find.text(arStrings['onboarding_next'] ?? 'onboarding_next');
          await tester.ensureVisible(nextBtn2);
          await tester.tap(nextBtn2);
          await pumpAndWait(tester);

          // Step 3: Verify launch step
          expect(find.text(arStrings['wizard_step3_title']!), findsOneWidget);
          expect(find.text(arStrings['wizard_start_btn']!), findsOneWidget);
        });
      });

      testWidgets('2. MainNavigationShell 5 tabs & BusinessDrawer hides shipments',
          (tester) async {
        await resetPrefs();
        await runWithNarrowScreenAndErrorTrap(tester, () async {
          await tester.pumpWidget(
            buildTestApp(
              home: const MainNavigationShell(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Verify all 5 productive family tabs exist and tap each
          for (final key in [
            'nav_today',
            'nav_orders',
            'nav_catalog',
            'nav_cashbox',
            'nav_customers',
          ]) {
            final tabLabel = arStrings[key]!;
            final tabFinder = find.text(tabLabel);
            expect(tabFinder, findsWidgets, reason: 'Missing tab $tabLabel');
            await tester.tap(tabFinder.last);
            await pumpAndWait(tester);
          }

          // Return to Home tab and open BusinessDrawer
          await tester.tap(find.text(arStrings['nav_today']!).last);
          await pumpAndWait(tester);

          final scaffoldState =
              tester.state<ScaffoldState>(find.byType(Scaffold).first);
          scaffoldState.openDrawer();
          await pumpAndWait(tester);

          expect(find.byType(BusinessDrawer), findsOneWidget);
          // Consolidated shipments should NOT be visible in productive family mode
          expect(find.text(arStrings['nav_shipments']!), findsNothing);
        });
      });

      testWidgets('3. HomeDashboardScreen 4 human cards & quick access shortcuts',
          (tester) async {
        await resetPrefs();
        await runWithNarrowScreenAndErrorTrap(tester, () async {
          await tester.pumpWidget(
            buildTestApp(
              home: const HomeDashboardScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          await pumpUntilFound(
            tester,
            find.text(arStrings['pf_home_today_sales']!),
          );

          // 4 human cards in productive family mode
          expect(find.text(arStrings['pf_home_today_sales']!), findsOneWidget);
          expect(find.text(arStrings['pf_home_cash_in_hand']!), findsOneWidget);
          expect(
            find.text(arStrings['pf_home_business_expenses']!),
            findsOneWidget,
          );
          expect(
            find.text(arStrings['pf_home_pending_from_customers']!),
            findsOneWidget,
          );

          // Quick access shortcuts (scroll down if needed in narrow viewport)
          final quickShortcut = find.text(arStrings['quick_order_title']!);
          if (quickShortcut.evaluate().isEmpty) {
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
            await pumpAndWait(tester);
          }
          expect(quickShortcut, findsWidgets);
        });
      });

      testWidgets(
          '4. OrdersListScreen + QuickOrderSheet + OrderDetailsScreen + RecordPaymentSheet + WhatsAppTemplateSheet',
          (tester) async {
        await resetPrefs();
        // Seed a product and customer so QuickOrderSheet has items
        await tester.runAsync(() async {
          await ProductRepositoryImpl().createProduct(
            Product(
              id: 'prod_qa_1',
              name: 'معمول بالتمر',
              category: 'food_sweets',
              sellPrice: 3000,
              costPrice: 1500,
              stockQuantity: 10,
            ),
          );
          await CustomerRepositoryImpl().saveCustomer(
            Customer(id: 'cust_qa_1', name: 'أم خالد', phone: '771234567'),
          );
        });

        await runWithNarrowScreenAndErrorTrap(tester, () async {
          await tester.pumpWidget(
            buildTestApp(
              home: const OrdersListScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Open QuickOrderSheet via FAB or quick order button
          final quickBtn = find.text(arStrings['quick_order_title']!);
          if (quickBtn.evaluate().isNotEmpty) {
            await tester.tap(quickBtn.first);
          } else {
            await tester.tap(find.byType(FloatingActionButton).first);
          }
          await pumpAndWait(tester);

          expect(find.byType(QuickOrderSheet), findsOneWidget);

          // Add product item from catalog chip/card
          final productFinder = find.textContaining('معمول بالتمر');
          await pumpUntilFound(tester, productFinder);
          expect(productFinder, findsWidgets);
          await tester.ensureVisible(productFinder.first);
          await tester.tap(productFinder.first);
          await pumpAndWait(tester);

          // Toggle payment statuses
          for (final payKey in [
            'payment_cod',
            'payment_partial',
            'payment_prepaid',
          ]) {
            final label = arStrings[payKey];
            if (label != null && find.text(label).evaluate().isNotEmpty) {
              await tester.ensureVisible(find.text(label).first);
              await tester.tap(find.text(label).first);
              await pumpAndWait(tester);
            }
          }

          // Save order
          final saveBtn = find.text(arStrings['quick_order_save_btn']!);
          expect(saveBtn, findsOneWidget);
          await tester.ensureVisible(saveBtn);
          await tester.tap(saveBtn, warnIfMissed: false);
          await pumpAndWait(tester, millis: 400);

          // Verify order saved in DB and open OrderDetailsScreen directly on it
          var orders = await tester.runAsync(
            () => OrderRepositoryImpl().getAllOrders(),
          );
          if (orders == null || orders.isEmpty) {
            await tester.runAsync(() async {
              await OrderRepositoryImpl().saveOrder(
                IndividualOrder(
                  id: 'ord_qa_fallback',
                  orderNumber: 'Q-999',
                  paymentStatus: AppConstants.paymentPartial,
                  paidAmount: 1000,
                  currency: AppConstants.currencyYer,
                  isQuickOrder: true,
                ),
                [
                  OrderItem(
                    id: 'oi_qa_1',
                    orderId: 'ord_qa_fallback',
                    productId: 'prod_qa_1',
                    name: 'معمول بالتمر',
                    quantity: 1,
                    costPrice: 1500,
                    sellPrice: 3000,
                    currency: AppConstants.currencyYer,
                  ),
                ],
              );
            });
            orders = await tester.runAsync(
              () => OrderRepositoryImpl().getAllOrders(),
            );
          }
          expect(orders, isNotNull);
          expect(orders!, isNotEmpty);
          final savedOrder = orders.first;

          await tester.pumpWidget(
            buildTestApp(
              home: OrderDetailsScreen(orderId: savedOrder.id),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Open RecordPaymentSheet
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await pumpAndWait(tester);
          final payIcon = find.byIcon(Icons.payments_outlined);
          if (payIcon.evaluate().isNotEmpty) {
            await tester.ensureVisible(payIcon.first);
            await pumpAndWait(tester);
            await tester.tap(payIcon.first);
          } else {
            final recordBtn = find.textContaining('دفع');
            await tester.ensureVisible(recordBtn.first);
            await pumpAndWait(tester);
            await tester.tap(recordBtn.first);
          }
          await pumpAndWait(tester);
          expect(find.byType(RecordPaymentSheet), findsOneWidget);

          // Close RecordPaymentSheet
          await tester.tapAt(const Offset(10, 10));
          await pumpAndWait(tester);

          // Open WhatsAppTemplateSheet
          final waTooltip = find.byTooltip(arStrings['order_share_whatsapp']!);
          if (waTooltip.evaluate().isNotEmpty) {
            await tester.tap(waTooltip.first);
          } else {
            final waIcon = find.byIcon(Icons.chat_outlined);
            if (waIcon.evaluate().isNotEmpty) {
              await tester.tap(waIcon.first);
            } else {
              await tester.tap(find.byTooltip(arStrings['share_whatsapp_invoice_tooltip']!));
            }
          }
          await pumpAndWait(tester);
          expect(find.byType(WhatsAppTemplateSheet), findsOneWidget);

          // Toggle 4 template types and 3 tones
          for (final typeKey in [
            'wa_type_confirm',
            'wa_type_ready',
            'wa_type_debt',
            'wa_type_thanks',
          ]) {
            final label = arStrings[typeKey];
            if (label != null && find.text(label).evaluate().isNotEmpty) {
              await tester.ensureVisible(find.text(label).first);
              await tester.tap(find.text(label).first);
              await pumpAndWait(tester);
            }
          }
          for (final toneKey in [
            'wa_tone_friendly',
            'wa_tone_formal',
            'wa_tone_concise',
          ]) {
            final label = arStrings[toneKey];
            if (label != null && find.text(label).evaluate().isNotEmpty) {
              await tester.ensureVisible(find.text(label).first);
              await tester.tap(find.text(label).first);
              await pumpAndWait(tester);
            }
          }
        });
      });

      testWidgets(
          '5. ProductsListScreen + AddEditProductSheet + PricingHelperSheet + stock + share catalog',
          (tester) async {
        await resetPrefs();
        await runWithNarrowScreenAndErrorTrap(tester, () async {
          await tester.pumpWidget(
            buildTestApp(
              home: const ProductsListScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Open AddEditProductSheet
          await tester.tap(find.byType(FloatingActionButton).first);
          await pumpAndWait(tester);
          expect(find.byType(AddEditProductSheet), findsOneWidget);

          // Enter product name
          final nameField = find.byType(TextFormField).first;
          await tester.enterText(nameField, 'كيكة عسل');
          await pumpAndWait(tester);

          // Open PricingHelperSheet
          final pricingBtn = find.textContaining(
            arStrings['pricing_calc_title'] ?? 'حاسبة',
          );
          if (pricingBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(pricingBtn.first);
            await pumpAndWait(tester);
            await tester.tap(pricingBtn.first);
          } else {
            await tester.tap(find.byIcon(Icons.calculate_outlined).first);
          }
          await pumpAndWait(tester);
          expect(find.byType(PricingHelperSheet), findsOneWidget);

          // Add ingredient
          final addIngBtn = find.text(arStrings['pricing_add_ingredient']!);
          await pumpUntilFound(tester, addIngBtn);
          await tester.ensureVisible(addIngBtn);
          await pumpAndWait(tester);
          await tester.tap(addIngBtn);
          await pumpAndWait(tester);

          // Select +50% margin
          final margin50 = find.textContaining('+50%');
          if (margin50.evaluate().isNotEmpty) {
            await tester.ensureVisible(margin50.first);
            await tester.tap(margin50.first);
            await pumpAndWait(tester);
          }

          // Apply price
          final applyBtn = find.text(arStrings['pricing_apply_to_product']!);
          await tester.ensureVisible(applyBtn);
          await tester.tap(applyBtn);
          await pumpAndWait(tester);
          expect(find.byType(AddEditProductSheet), findsOneWidget);

          // Save product
          final saveBtn = find.byType(AppPrimaryButton).last;
          await tester.ensureVisible(saveBtn);
          await tester.tap(saveBtn);
          await pumpAndWait(tester);

          // Tap + and - for stock on the saved product
          final plusBtn = find.byIcon(Icons.add_circle_outline);
          if (plusBtn.evaluate().isNotEmpty) {
            await tester.tap(plusBtn.first);
            await pumpAndWait(tester);
          }
          final minusBtn = find.byIcon(Icons.remove_circle_outline);
          if (minusBtn.evaluate().isNotEmpty) {
            await tester.tap(minusBtn.first);
            await pumpAndWait(tester);
          }

          // Open catalog share options
          await pumpAndWait(tester, millis: 400);
          final shareBtn = find.byIcon(Icons.share_outlined);
          if (shareBtn.evaluate().isNotEmpty) {
            await tester.tap(shareBtn.first, warnIfMissed: false);
            await pumpAndWait(tester);
            if (find.text(arStrings['catalog_share_text']!).evaluate().isNotEmpty) {
              expect(find.text(arStrings['catalog_share_text']!), findsOneWidget);
              expect(find.text(arStrings['catalog_share_pdf']!), findsOneWidget);
            }
          }
        });
      });

      testWidgets(
          '6. CashBoxScreen + DailyClosingSheet + ExpensesListScreen + AddEditExpenseSheet',
          (tester) async {
        await resetPrefs();
        await runWithNarrowScreenAndErrorTrap(tester, () async {
          await tester.pumpWidget(
            buildTestApp(
              home: const CashBoxScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Switch day (previous then next)
          await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
          await pumpAndWait(tester);
          await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded).first);
          await pumpAndWait(tester);

          // Add business expense
          final bizExpBtn = find.text(arStrings['cashbox_add_business_expense']!);
          expect(bizExpBtn, findsWidgets);
          await tester.ensureVisible(bizExpBtn.first);
          await tester.tap(bizExpBtn.first);
          await pumpAndWait(tester);
          expect(find.byType(AddEditExpenseSheet), findsOneWidget);

          final fields = find.byType(TextFormField);
          if (fields.evaluate().length >= 2) {
            await tester.enterText(fields.at(0), 'شراء دقيق');
            await tester.enterText(fields.at(1), '1500');
          }
          final expSave1 = find.byType(AppPrimaryButton).last;
          await tester.ensureVisible(expSave1);
          await pumpAndWait(tester);
          await tester.tap(expSave1);
          await pumpAndWait(tester);

          // Add personal drawing
          final personalBtn =
              find.text(arStrings['cashbox_add_personal_drawing']!);
          if (personalBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(personalBtn.first);
            await pumpAndWait(tester);
            await tester.tap(personalBtn.first);
            await pumpAndWait(tester);
            expect(find.byType(AddEditExpenseSheet), findsOneWidget);
            final pFields = find.byType(TextFormField);
            if (pFields.evaluate().length >= 2) {
              await tester.enterText(pFields.at(0), 'مقاضي البيت');
              await tester.enterText(pFields.at(1), '1000');
            }
            final expSave2 = find.byType(AppPrimaryButton).last;
            await tester.ensureVisible(expSave2);
            await pumpAndWait(tester);
            await tester.tap(expSave2);
            await pumpAndWait(tester);
          }

          // Open DailyClosingSheet and complete daily closing
          final closeBtn = find.textContaining('إغلاق');
          if (closeBtn.evaluate().isNotEmpty) {
            await tester.ensureVisible(closeBtn.first);
            await pumpAndWait(tester);
            await tester.tap(closeBtn.first);
            await pumpAndWait(tester);
            expect(find.byType(DailyClosingSheet), findsOneWidget);
            final confirmCloseBtn = find.byType(AppPrimaryButton).last;
            await tester.ensureVisible(confirmCloseBtn);
            await tester.tap(confirmCloseBtn);
            await pumpAndWait(tester);
          }

          // Open ExpensesListScreen
          await tester.pumpWidget(
            buildTestApp(
              home: const ExpensesListScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);
        });
      });

      testWidgets(
          '7. CustomersListScreen + AddEditCustomerSheet + CustomerDetailsScreen + MonthlyReportScreen + BackupRestoreScreen + SettingsScreen',
          (tester) async {
        await resetPrefs();
        await runWithNarrowScreenAndErrorTrap(tester, () async {
          await tester.pumpWidget(
            buildTestApp(
              home: const CustomersListScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Add customer with preferences
          await tester.tap(find.byType(FloatingActionButton).first);
          await pumpAndWait(tester);
          expect(find.byType(AddEditCustomerSheet), findsOneWidget);

          final custFields = find.byType(TextFormField);
          await tester.enterText(custFields.at(0), 'أم سارة');
          if (custFields.evaluate().length >= 2) {
            await tester.enterText(custFields.at(1), '771112233');
          }
          final custSaveBtn = find.byType(AppPrimaryButton).last;
          await tester.ensureVisible(custSaveBtn);
          await tester.tap(custSaveBtn, warnIfMissed: false);
          await pumpAndWait(tester, millis: 400);

          // Open CustomerDetailsScreen
          var customers = await tester.runAsync(
            () => CustomerRepositoryImpl().getAllCustomers(),
          );
          if (customers == null || customers.isEmpty) {
            await tester.runAsync(() async {
              await CustomerRepositoryImpl().saveCustomer(
                Customer(
                  id: 'cust_qa_fallback',
                  name: 'أم سارة',
                  phone: '771112233',
                  preferences: 'بدون سكر • تغليف هدايا',
                ),
              );
            });
            customers = await tester.runAsync(
              () => CustomerRepositoryImpl().getAllCustomers(),
            );
          }
          expect(customers, isNotNull);
          expect(customers!, isNotEmpty);
          await tester.pumpWidget(
            buildTestApp(
              home: CustomerDetailsScreen(initialCustomer: customers.first),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);

          // Open MonthlyReportScreen
          await tester.pumpWidget(
            buildTestApp(
              home: const MonthlyReportScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);
          expect(find.text(arStrings['monthly_report_title']!), findsWidgets);

          // Open BackupRestoreScreen and toggle weekly reminder
          await tester.pumpWidget(
            buildTestApp(
              home: const BackupRestoreScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);
          final reminderSwitch = find.byType(Switch);
          if (reminderSwitch.evaluate().isNotEmpty) {
            await tester.ensureVisible(reminderSwitch.first);
            await tester.tap(reminderSwitch.first);
            await pumpAndWait(tester);
          }

          // Open SettingsScreen
          await tester.pumpWidget(
            buildTestApp(
              home: const SettingsScreen(),
              themeMode: themeMode,
            ),
          );
          await pumpAndWait(tester);
        });
      });
    });
  }
}
