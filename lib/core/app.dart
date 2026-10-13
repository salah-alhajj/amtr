import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'localization/localization.dart';
import 'theme/theme.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/navigation/main_navigation_shell.dart';
import 'package:mosaed/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';

class RetailAssistantApp extends StatelessWidget {
  const RetailAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    LocalJsonLocalization.delegate.directories = ['i18n'];
    final orderRepo = OrderRepositoryImpl();
    final shipmentRepo = ShipmentRepositoryImpl();
    final customerRepo = CustomerRepositoryImpl();

    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleBloc>(
          create: (_) => LocaleBloc()..add(const LoadPersistedLocale()),
        ),
        BlocProvider<ThemeBloc>(
          create: (_) => ThemeBloc()..add(const LoadPersistedTheme()),
        ),
        BlocProvider<DashboardBloc>(
          create: (_) => DashboardBloc(
            orderRepo: orderRepo,
            shipmentRepo: shipmentRepo,
            customerRepo: customerRepo,
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
      ],
      child: BlocBuilder<LocaleBloc, LocaleState>(
        builder: (context, localeState) {
          return BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              return MaterialApp(
                title: 'app_name'.i18n(),
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
                  const AppLocalizationsDelegate(),
                  LocalJsonLocalization.delegate,
                ],
                builder: (context, child) {
                  return Directionality(
                    textDirection: localeState.textDirection,
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: PreferencesService.instance.isOnboardingCompleted()
                    ? const MainNavigationShell()
                    : const OnboardingScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
