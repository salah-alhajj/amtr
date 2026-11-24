import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/expenses/presentation/screens/expenses_list_screen.dart';
import 'package:mosaed/features/expenses/presentation/widgets/add_edit_expense_sheet.dart';
import 'package:mosaed/features/manufacturing/data/repositories/manufacturing_template_repository.dart';
import 'package:mosaed/features/manufacturing/data/repositories/raw_material_repository.dart';
import 'package:mosaed/features/manufacturing/presentation/screens/materials_and_templates_screen.dart';
import 'package:mosaed/features/manufacturing/presentation/widgets/add_edit_material_sheet.dart';
import 'package:mosaed/features/manufacturing/presentation/widgets/production_recipe_builder_sheet.dart';
import 'package:mosaed/features/products/data/product_ingredient_repository.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/products/presentation/screens/products_list_screen.dart';
import 'package:mosaed/features/products/presentation/widgets/add_edit_product_sheet.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:mosaed/features/suppliers/presentation/bloc/suppliers_bloc.dart';
import 'package:mosaed/features/suppliers/presentation/screens/supplier_details_screen.dart';
import 'package:mosaed/features/suppliers/presentation/screens/suppliers_list_screen.dart';
import 'package:mosaed/features/suppliers/presentation/widgets/add_edit_supplier_sheet.dart';
import 'package:mosaed/models/expense.dart';
import 'package:mosaed/models/manufacturing_template.dart';
import 'package:mosaed/models/product.dart';
import 'package:mosaed/models/product_ingredient.dart';
import 'package:mosaed/models/raw_material.dart';
import 'package:mosaed/models/supplier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    LocalJsonLocalization.delegate.directories = ['i18n'];
    await LocalizationHelper.load('ar');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    await PreferencesService.instance.setBusinessMode(
      AppConstants.businessModeProductiveFamily,
    );
    await PreferencesService.instance.setMultiCurrencyEnabled(false);

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 9,
      onCreate: (database, version) =>
          AppDatabase.instance.createDBForTesting(database),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.init();
  });

  tearDown(() async {
    await db.close();
    AppDatabase.setTestDatabase(null);
  });

  Widget buildHarness({
    required Widget home,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    final productRepo = ProductRepositoryImpl();
    final expenseRepo = ExpenseRepositoryImpl();
    final supplierRepo = SupplierRepositoryImpl();

    return MultiBlocProvider(
      key: UniqueKey(),
      providers: [
        BlocProvider<LocaleBloc>(create: (_) => LocaleBloc()),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
        BlocProvider<BusinessModeCubit>(
          create: (_) => BusinessModeCubit()..loadFromPreferences(),
        ),
        BlocProvider<ProductsBloc>(
          create: (_) =>
              ProductsBloc(repository: productRepo)..add(const LoadProducts()),
        ),
        BlocProvider<ExpensesBloc>(
          create: (_) =>
              ExpensesBloc(repository: expenseRepo)..add(const LoadExpenses()),
        ),
        BlocProvider<SuppliersBloc>(
          create: (_) =>
              SuppliersBloc(repository: supplierRepo)..add(const LoadSuppliers()),
        ),
      ],
      child: MaterialApp(
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
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: home,
      ),
    );
  }

  Future<void> pumpAndWait(WidgetTester tester, {int millis = 150}) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: millis)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  group('1) SQLite v9 Migration & Backup Round-Trip', () {
    test('v9 schema has suppliers, raw_materials, manufacturing_templates & new columns',
        () async {
      final tables = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      ))
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        tables,
        containsAll([
          'suppliers',
          'raw_materials',
          'manufacturing_templates',
          'manufacturing_template_items',
        ]),
      );

      final prodCols = (await db.rawQuery('PRAGMA table_info(products);'))
          .map((c) => c['name'] as String)
          .toSet();
      expect(
        prodCols,
        containsAll(['supplierId', 'productType', 'batchYield', 'templateId']),
      );

      final expCols = (await db.rawQuery('PRAGMA table_info(expenses);'))
          .map((c) => c['name'] as String)
          .toSet();
      expect(expCols, containsAll(['recurrence', 'isPettyCash', 'supplierId']));

      final ingCols =
          (await db.rawQuery('PRAGMA table_info(product_ingredients);'))
              .map((c) => c['name'] as String)
              .toSet();
      expect(
        ingCols,
        containsAll(['itemType', 'materialId', 'quantity', 'unit', 'unitCost']),
      );
    });

    test('exportAllDataToJson & importAllDataFromJson preserve v9 data', () async {
      final supplierRepo = SupplierRepositoryImpl();
      final matRepo = RawMaterialRepository();
      final tplRepo = ManufacturingTemplateRepository();

      final sup = Supplier(id: 'sup_1', name: 'جملة البركة', category: 'sup_cat_wholesale');
      await supplierRepo.createSupplier(sup);

      final mat = RawMaterial(
        id: 'mat_1',
        name: 'دقيق فاخر',
        unit: 'كجم',
        unitCost: 600,
        supplierId: sup.id,
      );
      await matRepo.save(mat);

      final tpl = ManufacturingTemplate(
        id: 'tpl_1',
        name: 'قالب معمول',
        yieldCount: 20,
        items: [
          const ManufacturingTemplateItem(
            id: 'ti_1',
            templateId: 'tpl_1',
            itemType: AppConstants.costItemMaterial,
            materialId: 'mat_1',
            name: 'دقيق فاخر',
            quantity: 2,
            unit: 'كجم',
            unitCost: 600,
          ),
          const ManufacturingTemplateItem(
            id: 'ti_2',
            templateId: 'tpl_1',
            itemType: AppConstants.costItemLabor,
            name: 'أجر يد',
            quantity: 1,
            unitCost: 800,
          ),
        ],
      );
      await tplRepo.saveTemplate(tpl);

      final exported = await AppDatabase.instance.exportAllDataToJson();
      expect((exported['suppliers'] as List).length, 1);
      expect((exported['raw_materials'] as List).length, 1);
      expect((exported['manufacturing_templates'] as List).length, 1);
      expect((exported['manufacturing_template_items'] as List).length, 2);

      // Clear DB & restore
      await db.delete('manufacturing_template_items');
      await db.delete('manufacturing_templates');
      await db.delete('raw_materials');
      await db.delete('suppliers');

      await AppDatabase.instance.importAllDataFromJson(exported);

      final restoredTemplates = await tplRepo.getAllTemplates();
      expect(restoredTemplates.length, 1);
      expect(restoredTemplates.first.items.length, 2);
      expect(restoredTemplates.first.totalBatchCost, 2000.0);
      expect(restoredTemplates.first.unitCost, 100.0);
    });
  });

  group('2) Suppliers, Manufacturing Templates & Expenses Lifecycle', () {
    test('Supplier deletion unlinks products, materials & expenses safely',
        () async {
      final supplierRepo = SupplierRepositoryImpl();
      final productRepo = ProductRepositoryImpl();
      final matRepo = RawMaterialRepository();
      final expenseRepo = ExpenseRepositoryImpl();

      final sup = Supplier(id: 'sup_del', name: 'مورد التغليف');
      await supplierRepo.createSupplier(sup);

      await productRepo.createProduct(
        Product(
          id: 'p_sup',
          name: 'علب هدايا',
          sellPrice: 1500,
          supplierId: sup.id,
          productType: AppConstants.productTypeResale,
        ),
      );
      await matRepo.save(
        RawMaterial(id: 'm_sup', name: 'شريط ساتان', supplierId: sup.id),
      );
      await expenseRepo.createExpense(
        Expense(
          id: 'e_sup',
          title: 'شراء كراتين',
          amount: 5000,
          supplierId: sup.id,
          isPettyCash: true,
        ),
      );

      final counts = await supplierRepo.getLinkedProductCounts();
      expect(counts[sup.id], 1);

      await supplierRepo.deleteSupplier(sup.id);

      final prod = await productRepo.getProductById('p_sup');
      final mat = await matRepo.getById('m_sup');
      final exps = await expenseRepo.getAllExpenses();

      expect(prod, isNotNull);
      expect(prod!.supplierId, isNull);
      expect(mat, isNotNull);
      expect(mat!.supplierId, isNull);
      expect(exps.first.supplierId, isNull);
    });

    test('Manufactured product recipe + batch production + ExpensesBloc recurring totals',
        () async {
      final productRepo = ProductRepositoryImpl();
      final ingRepo = ProductIngredientRepository();

      final mfgProduct = Product(
        id: 'p_mfg_1',
        name: 'بخور ملكي',
        sellPrice: 3500,
        costPrice: 1500,
        productType: AppConstants.productTypeManufactured,
        batchYield: 10,
        trackStock: true,
        stockQuantity: 5,
      );
      await productRepo.createProduct(mfgProduct);
      await ingRepo.replaceForProduct('p_mfg_1', [
        const ProductIngredient(
          id: 'ing_1',
          productId: 'p_mfg_1',
          name: 'عود مطحون',
          cost: 10000,
          yieldCount: 10,
          itemType: AppConstants.costItemMaterial,
          quantity: 2,
          unitCost: 5000,
        ),
        const ProductIngredient(
          id: 'ing_2',
          productId: 'p_mfg_1',
          name: 'علب زجاجية',
          cost: 3000,
          yieldCount: 10,
          itemType: AppConstants.costItemPackaging,
          unitCost: 3000,
        ),
        const ProductIngredient(
          id: 'ing_3',
          productId: 'p_mfg_1',
          name: 'أجر تصنيع',
          cost: 2000,
          yieldCount: 10,
          itemType: AppConstants.costItemLabor,
          unitCost: 2000,
        ),
      ]);

      final pBloc = ProductsBloc(repository: productRepo)
        ..add(const LoadProducts());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      pBloc.add(AdjustProductStockEvent(mfgProduct.id, mfgProduct.batchYield));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final updatedProd = await productRepo.getProductById(mfgProduct.id);
      expect(updatedProd!.stockQuantity, 15);
      await pBloc.close();

      final expenseRepo = ExpenseRepositoryImpl();
      await expenseRepo.createExpense(
        Expense(
          id: 'exp_daily',
          title: 'مواصلات يومية',
          amount: 1000,
          recurrence: AppConstants.expenseRecurrenceDaily,
          isPettyCash: true,
        ),
      );
      await expenseRepo.createExpense(
        Expense(
          id: 'exp_weekly',
          title: 'تنظيف أسبوعي',
          amount: 2500,
          recurrence: AppConstants.expenseRecurrenceWeekly,
        ),
      );
      await expenseRepo.createExpense(
        Expense(
          id: 'exp_monthly',
          title: 'إيجار شهري',
          amount: 30000,
          recurrence: AppConstants.expenseRecurrenceMonthly,
        ),
      );

      final eBloc = ExpensesBloc(repository: expenseRepo)
        ..add(const LoadExpenses());
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(eBloc.state, isA<ExpensesLoaded>());
      final loaded = eBloc.state as ExpensesLoaded;
      expect(loaded.pettyCashTotalInYer, 1000.0);
      expect(loaded.dailyTotalInYer, 1000.0);
      expect(loaded.weeklyTotalInYer, 2500.0);
      expect(loaded.monthlyTotalInYer, 30000.0);
      // 1000*30 + 2500*4 + 30000 = 70000
      expect(loaded.estimatedMonthlyRecurringInYer, 70000.0);

      eBloc.add(const FilterExpensesByFrequency('petty_cash'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final pettyFiltered = eBloc.state as ExpensesLoaded;
      expect(pettyFiltered.displayedExpenses.length, 1);
      expect(pettyFiltered.displayedExpenses.first.id, 'exp_daily');
      await eBloc.close();
    });
  });

  group('3) Narrow-Screen 360x740 Light & Dark UI Overflow Tests', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final modeName = mode == ThemeMode.light ? 'Light' : 'Dark';

      testWidgets('Suppliers, Materials/Templates, Products & Expenses [$modeName]',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          prevOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = prevOnError);

        final sup = Supplier(
          id: 'ui_sup_1',
          name: 'مورد النخبة للمواد الخام والتغليف',
          phone: '771234567',
          category: 'sup_cat_materials',
        );
        await tester.runAsync(() => SupplierRepositoryImpl().createSupplier(sup));
        await tester.runAsync(
          () => RawMaterialRepository().save(
            RawMaterial(
              id: 'ui_mat_1',
              name: 'زعفران فاخر',
              unit: 'جرام',
              unitCost: 500,
              supplierId: sup.id,
            ),
          ),
        );
        await tester.runAsync(
          () => ManufacturingTemplateRepository().saveTemplate(
            ManufacturingTemplate(
              id: 'ui_tpl_1',
              name: 'قالب بخور فاخر',
              yieldCount: 12,
              items: [
                const ManufacturingTemplateItem(
                  id: 'ui_ti_1',
                  templateId: 'ui_tpl_1',
                  name: 'زعفران فاخر',
                  quantity: 2,
                  unit: 'جرام',
                  unitCost: 500,
                ),
              ],
            ),
          ),
        );
        await tester.runAsync(
          () => ProductRepositoryImpl().createProduct(
            Product(
              id: 'ui_prod_1',
              name: 'معمول بالتمر الفاخر',
              sellPrice: 4000,
              costPrice: 1800,
              supplierId: sup.id,
              productType: AppConstants.productTypeManufactured,
              batchYield: 12,
              trackStock: true,
              stockQuantity: 10,
            ),
          ),
        );
        await tester.runAsync(
          () => ExpenseRepositoryImpl().createExpense(
            Expense(
              id: 'ui_exp_1',
              title: 'مواصلات يومية ونثريات',
              amount: 1500,
              recurrence: AppConstants.expenseRecurrenceDaily,
              isPettyCash: true,
              supplierId: sup.id,
            ),
          ),
        );

        // 1. SuppliersListScreen + AddEditSupplierSheet + SupplierDetailsScreen
        await tester.pumpWidget(
          buildHarness(home: const SuppliersListScreen(), themeMode: mode),
        );
        await pumpAndWait(tester);
        await tester.pumpWidget(
          buildHarness(
            home: SupplierDetailsScreen(supplier: sup),
            themeMode: mode,
          ),
        );
        await pumpAndWait(tester);
        await tester.pumpWidget(
          buildHarness(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AddEditSupplierSheet(onSave: (_) {}),
              ),
            ),
            themeMode: mode,
          ),
        );
        await pumpAndWait(tester);

        // 2. MaterialsAndTemplatesScreen + AddEditMaterialSheet + ProductionRecipeBuilderSheet
        await tester.pumpWidget(
          buildHarness(
            home: const MaterialsAndTemplatesScreen(),
            themeMode: mode,
          ),
        );
        await pumpAndWait(tester);
        await tester.pumpWidget(
          buildHarness(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AddEditMaterialSheet(onSave: (_) {}),
              ),
            ),
            themeMode: mode,
          ),
        );
        await pumpAndWait(tester);
        await tester.pumpWidget(
          buildHarness(
            home: const Scaffold(
              body: ProductionRecipeBuilderSheet(
                currency: AppConstants.currencyYer,
                productId: 'ui_prod_1',
              ),
            ),
            themeMode: mode,
          ),
        );
        await pumpAndWait(tester);

        // 3. ProductsListScreen + AddEditProductSheet
        await tester.pumpWidget(
          buildHarness(home: const ProductsListScreen(), themeMode: mode),
        );
        await pumpAndWait(tester);
        await tester.pumpWidget(
          buildHarness(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AddEditProductSheet(onSave: (_) {}),
              ),
            ),
            themeMode: mode,
          ),
        );
        await pumpAndWait(tester);

        // 4. ExpensesListScreen + AddEditExpenseSheet
        await tester.pumpWidget(
          buildHarness(home: const ExpensesListScreen(), themeMode: mode),
        );
        await pumpAndWait(tester);
        await tester.pumpWidget(
          buildHarness(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AddEditExpenseSheet(onSave: (_) {}),
              ),
            ),
            themeMode: mode,
          ),
        );
        await pumpAndWait(tester);

        await tester.pump(const Duration(seconds: 10));

        expect(
          errors,
          isEmpty,
          reason: errors.map((e) => e.exceptionAsString()).join('\n'),
        );
      });
    }
  });
}
