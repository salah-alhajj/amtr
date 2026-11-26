import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'localization/localization.dart';
import 'theme/theme.dart';
import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/couriers/data/repositories/courier_repository_impl.dart';
import 'package:mosaed/features/couriers/presentation/bloc/couriers_bloc.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/navigation/main_navigation_shell.dart';
import 'package:mosaed/features/onboarding/presentation/screens/business_setup_wizard_screen.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:mosaed/features/suppliers/presentation/bloc/suppliers_bloc.dart';

class RetailAssistantApp extends StatelessWidget {
  const RetailAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    final orderRepo = OrderRepositoryImpl();
    final shipmentRepo = ShipmentRepositoryImpl();
    final customerRepo = CustomerRepositoryImpl();
    final productRepo = ProductRepositoryImpl();
    final expenseRepo = ExpenseRepositoryImpl();
    final supplierRepo = SupplierRepositoryImpl();
    final courierRepo = CourierRepositoryImpl();

    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleBloc>(
          create: (_) => LocaleBloc()..add(const LoadPersistedLocale()),
        ),
        BlocProvider<ThemeBloc>(
          create: (_) => ThemeBloc()..add(const LoadPersistedTheme()),
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
              ShipmentsBloc(repository: shipmentRepo)
                ..add(const LoadShipments()),
        ),
        BlocProvider<CustomersBloc>(
          create: (_) =>
              CustomersBloc(
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
        BlocProvider<SuppliersBloc>(
          create: (_) =>
              SuppliersBloc(repository: supplierRepo)..add(const LoadSuppliers()),
        ),
        BlocProvider<CouriersBloc>(
          create: (_) =>
              CouriersBloc(repository: courierRepo)..add(const LoadCouriers()),
        ),
      ],
      child: BlocBuilder<LocaleBloc, LocaleState>(
        builder: (context, localeState) {
          return BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp(
                title: 'app_name'.i18n(),
                onGenerateTitle: (_) => 'app_name'.i18n(),
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeState.themeMode,
                locale: localeState.locale,
                supportedLocales: AppLocalizationsDelegate.supportedLocales,
                localizationsDelegates: [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  // يُستخدم AppLocalizationsDelegate حصراً بدلاً من LocalJsonLocalization.delegate
                  // لمنع الكتابة فوق طبقة اللهجة اليمنية المختارة بملف i18n/ar.json
                  AppLocalizationsDelegate(
                    arabicDialect: localeState.arabicDialect,
                  ),
                ],
                builder: (context, child) {
                  return Directionality(
                    textDirection: localeState.textDirection,
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: PreferencesService.instance.isOnboardingCompleted()
                    ? const MainNavigationShell()
                    : const BusinessSetupWizardScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
