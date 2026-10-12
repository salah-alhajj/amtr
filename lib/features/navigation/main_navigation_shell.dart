import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/business_drawer.dart';
import '../customers/presentation/screens/customers_list_screen.dart';
import '../dashboard/presentation/screens/home_dashboard_screen.dart';
import '../orders/presentation/screens/orders_list_screen.dart';
import '../settings/presentation/screens/settings_screen.dart';
import '../shipments/presentation/screens/shipments_list_screen.dart';
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

  void _onDestinationSelected(int idx) {
    if (_currentIndex != idx) {
      setState(() => _currentIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeState = context.watch<LocaleBloc>().state;
    final langCode = localeState.locale.languageCode;

    final screens = [
      HomeDashboardScreen(
        key: ValueKey('home_$langCode'),
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        onNavigateTab: _onDestinationSelected,
      ),
      OrdersListScreen(key: ValueKey('orders_$langCode')),
      ShipmentsListScreen(key: ValueKey('shipments_$langCode')),
      CustomersListScreen(key: ValueKey('customers_$langCode')),
      SettingsScreen(key: ValueKey('settings_$langCode')),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navActiveBlue = isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    final navActiveGreen = isDark ? AppColors.darkPrimaryGreen : AppColors.primaryGreen;
    final navActiveNavy = isDark ? AppColors.darkVibrantTeal : AppColors.deepNavy;

    return MainNavigationScope(
      currentIndex: _currentIndex,
      navigateTo: _onDestinationSelected,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: BusinessDrawer(
          onNavigateHome: () => _onDestinationSelected(0),
          onNavigateOrders: () => _onDestinationSelected(1),
          onNavigateShipments: () => _onDestinationSelected(2),
          onNavigateCustomers: () => _onDestinationSelected(3),
          onNavigateSettings: () => _onDestinationSelected(4),
        ),
        body: DirectionalSlideIndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: AmtrBottomNavBar(
          selectedIndex: _currentIndex,
          onItemSelected: _onDestinationSelected,
          items: [
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
          ],
        ),
      ),
    );
  }
}
