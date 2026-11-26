import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/business/business_mode_cubit.dart';
import '../../core/localization/localization.dart';
import '../../core/services/data_sync_bus.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/business_drawer.dart';
import '../cashbox/presentation/screens/cashbox_screen.dart';
import '../customers/presentation/screens/customers_list_screen.dart';
import '../dashboard/presentation/screens/home_dashboard_screen.dart';
import '../orders/presentation/screens/orders_list_screen.dart';
import '../products/presentation/screens/products_list_screen.dart';
import '../settings/presentation/screens/settings_screen.dart';
import '../shipments/presentation/screens/shipments_list_screen.dart';
import '../about/presentation/screens/about_app_screen.dart';
import 'widgets/amtr_bottom_nav_bar.dart';
import 'widgets/directional_slide_indexed_stack.dart';

/// نطاق مشاركة التنقل لتمكين أي عنصر أو شاشة فرعية من التبديل بين ألسنة الشل
class MainNavigationScope extends InheritedWidget {
  final int currentIndex;
  final void Function(int index) navigateTo;

  const MainNavigationScope({
    super.key,
    required this.currentIndex,
    required this.navigateTo,
    required super.child,
  });

  static MainNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainNavigationScope>();
  }

  static MainNavigationScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No MainNavigationScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(MainNavigationScope oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<DataDomain>? _syncSub;

  @override
  void initState() {
    super.initState();
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (domain == DataDomain.businessMode && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _onDestinationSelected(int idx) {
    if (_currentIndex != idx) {
      setState(() => _currentIndex = idx);
    }
  }

  bool _isProductiveFamily(BuildContext context) {
    try {
      return context.watch<BusinessModeCubit>().state.isProductiveFamily;
    } catch (_) {
      return PreferencesService.instance.isProductiveFamilyMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeState = context.watch<LocaleBloc>().state;
    final langCode = localeState.locale.languageCode;
    final localeKey = '${langCode}_${localeState.arabicDialect}';
    final isProductiveFamily = _isProductiveFamily(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navActiveBlue = isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    final navActiveGreen = isDark ? AppColors.darkPrimaryGreen : AppColors.primaryGreen;
    final navActiveNavy = isDark ? AppColors.darkVibrantTeal : AppColors.deepNavy;

    final List<Widget> screens;
    final List<AmtrNavItemData> navItems;

    if (isProductiveFamily) {
      screens = [
        HomeDashboardScreen(
          key: ValueKey('home_$localeKey'),
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateTab: _onDestinationSelected,
        ),
        OrdersListScreen(key: ValueKey('orders_$localeKey')),
        ProductsListScreen(key: ValueKey('catalog_$localeKey')),
        CashBoxScreen(key: ValueKey('cashbox_$localeKey')),
        CustomersListScreen(key: ValueKey('customers_$localeKey')),
      ];
      navItems = [
        AmtrNavItemData(
          icon: Icons.today_outlined,
          activeIcon: Icons.today_rounded,
          label: 'nav_today'.i18n(),
          activeColor: navActiveBlue,
        ),
        AmtrNavItemData(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'nav_orders'.i18n(),
          activeColor: navActiveBlue,
        ),
        AmtrNavItemData(
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront_rounded,
          label: 'nav_catalog'.i18n(),
          activeColor: navActiveGreen,
        ),
        AmtrNavItemData(
          icon: Icons.account_balance_wallet_outlined,
          activeIcon: Icons.account_balance_wallet_rounded,
          label: 'nav_cashbox'.i18n(),
          activeColor: navActiveGreen,
        ),
        AmtrNavItemData(
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          label: 'nav_customers'.i18n(),
          activeColor: navActiveNavy,
        ),
      ];
    } else {
      screens = [
        HomeDashboardScreen(
          key: ValueKey('home_$localeKey'),
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onNavigateTab: _onDestinationSelected,
        ),
        OrdersListScreen(key: ValueKey('orders_$localeKey')),
        ShipmentsListScreen(key: ValueKey('shipments_$localeKey')),
        CustomersListScreen(key: ValueKey('customers_$localeKey')),
        SettingsScreen(key: ValueKey('settings_$localeKey')),
      ];
      navItems = [
        AmtrNavItemData(
          icon: Icons.analytics_outlined,
          activeIcon: Icons.analytics_rounded,
          label: 'nav_home'.i18n(),
          activeColor: navActiveBlue,
        ),
        AmtrNavItemData(
          icon: Icons.inventory_2_outlined,
          activeIcon: Icons.inventory_2_rounded,
          label: 'nav_orders'.i18n(),
          activeColor: navActiveBlue,
        ),
        AmtrNavItemData(
          icon: Icons.local_shipping_outlined,
          activeIcon: Icons.local_shipping_rounded,
          label: 'nav_shipments'.i18n(),
          activeColor: navActiveGreen,
        ),
        AmtrNavItemData(
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          label: 'nav_customers'.i18n(),
          activeColor: navActiveNavy,
        ),
        AmtrNavItemData(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'nav_settings'.i18n(),
          activeColor: isDark ? AppColors.darkPrimaryBlue : AppColors.deepNavy,
        ),
      ];
    }

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return MainNavigationScope(
      currentIndex: safeIndex,
      navigateTo: _onDestinationSelected,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: BusinessDrawer(
          onNavigateHome: () => _onDestinationSelected(0),
          onNavigateOrders: () => _onDestinationSelected(1),
          onNavigateShipments: isProductiveFamily
              ? null
              : () => _onDestinationSelected(2),
          onNavigateCatalog: isProductiveFamily
              ? () => _onDestinationSelected(2)
              : null,
          onNavigateCashbox: isProductiveFamily
              ? () => _onDestinationSelected(3)
              : null,
          onNavigateCustomers: () =>
              _onDestinationSelected(isProductiveFamily ? 4 : 3),
          onNavigateSettings: isProductiveFamily
              ? null
              : () => _onDestinationSelected(4),
          onNavigateAbout: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutAppScreen()),
            );
          },
        ),
        body: DirectionalSlideIndexedStack(
          index: safeIndex,
          children: screens,
        ),
        bottomNavigationBar: AmtrBottomNavBar(
          selectedIndex: safeIndex,
          onItemSelected: _onDestinationSelected,
          items: navItems,
        ),
      ),
    );
  }
}
