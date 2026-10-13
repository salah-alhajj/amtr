import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../localization/localization.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import 'design_system.dart';
import '../../features/backup/presentation/screens/backup_restore_screen.dart';
import '../../features/customers/presentation/screens/customers_list_screen.dart';
import '../../features/orders/presentation/screens/orders_list_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shipments/presentation/screens/shipments_list_screen.dart';
import '../../features/about/presentation/screens/about_app_screen.dart';

/// دراور تجاري ومالي احترافي مصقول يعكس هوية المال والأعمال والشحن
class BusinessDrawer extends StatelessWidget {
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateOrders;
  final VoidCallback? onNavigateShipments;
  final VoidCallback? onNavigateCustomers;
  final VoidCallback? onNavigateSettings;
  final VoidCallback? onNavigateAbout;

  const BusinessDrawer({
    super.key,
    this.onNavigateHome,
    this.onNavigateOrders,
    this.onNavigateShipments,
    this.onNavigateCustomers,
    this.onNavigateSettings,
    this.onNavigateAbout,
  });

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final currencyService = CurrencyService.instance;
    final activeCurrency = currencyService.activeDisplayCurrency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkScaffoldBackground : AppColors.backgroundLight,
      child: SafeArea(
        child: Column(
          children: [
            // ترويسة دراور الأعمال المصقولة (Apple Business Header)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorderDivider : AppColors.borderDivider,
                    width: 0.8,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogo(
                        size: 44,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'app_name'.i18n(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepNavy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const AppPulsingDot(
                                  color: AppColors.primaryGreen,
                                  size: 6,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'drawer_sqlite_offline'.i18n(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // شريط أسعار الصرف الحية المصغر (Live Currency Ticker)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showQuickCurrencyConverter(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceMuted : const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE5E7EB),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 1. سعر صرف الريال السعودي
                            Expanded(
                              child: _buildRateTickerItem(
                                symbolWidget: SaudiRiyalIcon(
                                  width: 12,
                                  height: 12,
                                  color: isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue,
                                ),
                                prefixNumber: '1',
                                valueText: '${NumberFormat('#,##0.##').format(currencyService.sarToYer)} ${AppConstants.yerSymbol}',
                                isDark: isDark,
                              ),
                            ),
                            Container(width: 0.8, height: 24, color: isDark ? AppColors.darkBorderDivider : AppColors.borderDivider),
                            // 2. سعر صرف الدولار الأمريكي
                            Expanded(
                              child: _buildRateTickerItem(
                                symbolWidget: Text(
                                  '\$',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue,
                                  ),
                                ),
                                prefixNumber: '1',
                                valueText: '${NumberFormat('#,##0.##').format(currencyService.usdToYer)} ${AppConstants.yerSymbol}',
                                isDark: isDark,
                              ),
                            ),
                            Container(width: 0.8, height: 24, color: isDark ? AppColors.darkBorderDivider : AppColors.borderDivider),
                            // 3. محول العملات والعملة النشطة
                            Expanded(
                              child: _buildCalculatorTickerItem(
                                context: context,
                                activeCurrency: activeCurrency,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // قائمة الخيارات المالية واللوجستية
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  _buildSectionHeader('drawer_operations_logistics'.i18n()),
                  _DrawerMenuItem(
                    icon: Icons.analytics_rounded,
                    title: 'nav_home'.i18n(),
                    subtitle: 'drawer_dashboard_charts'.i18n(),
                    iconColor: AppColors.primaryBlue,
                    onTap: () {
                      Navigator.pop(context);
                      onNavigateHome?.call();
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'nav_orders'.i18n(),
                    subtitle: 'drawer_orders_pricing'.i18n(),
                    iconColor: AppColors.deepNavy,
                    onTap: () {
                      Navigator.pop(context);
                      if (onNavigateOrders != null) {
                        onNavigateOrders!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrdersListScreen()),
                        );
                      }
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.local_shipping_rounded,
                    title: 'nav_shipments'.i18n(),
                    subtitle: 'drawer_shipments_containers'.i18n(),
                    iconColor: AppColors.primaryGreen,
                    onTap: () {
                      Navigator.pop(context);
                      if (onNavigateShipments != null) {
                        onNavigateShipments!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ShipmentsListScreen()),
                        );
                      }
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.people_alt_rounded,
                    title: 'nav_customers'.i18n(),
                    subtitle: 'drawer_customers_debts'.i18n(),
                    iconColor: AppColors.vibrantTeal,
                    onTap: () {
                      Navigator.pop(context);
                      if (onNavigateCustomers != null) {
                        onNavigateCustomers!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CustomersListScreen()),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 12),
                  _buildSectionHeader('drawer_finance_data'.i18n()),

                  _DrawerMenuItem(
                    icon: Icons.currency_exchange_rounded,
                    title: 'currencies_and_exchange'.i18n(),
                    subtitle: 'drawer_exchange_rates'.i18n(),
                    iconColor: AppColors.statusWarning,
                    onTap: () {
                      Navigator.pop(context);
                      if (onNavigateSettings != null) {
                        onNavigateSettings!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      }
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.save_alt_rounded,
                    title: 'backup_and_restore'.i18n(),
                    subtitle: 'drawer_export_json'.i18n(),
                    iconColor: AppColors.primaryBlue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
                      );
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.settings_suggest_rounded,
                    title: 'nav_settings'.i18n(),
                    subtitle: 'drawer_language_theme_info'.i18n(),
                    iconColor: AppColors.textSecondary,
                    onTap: () {
                      Navigator.pop(context);
                      if (onNavigateSettings != null) {
                        onNavigateSettings!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      }
                    },
                  ),
                  _DrawerMenuItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'drawer_about_app'.i18n(),
                    subtitle: 'drawer_about_app_desc'.i18n(),
                    iconColor: AppColors.primaryBlue,
                    onTap: () {
                      Navigator.pop(context);
                      if (onNavigateAbout != null) {
                        onNavigateAbout!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // تذييل الدراور مع قائمة منسدلة لاختيار لغة التطبيق
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorderDivider : AppColors.borderDivider,
                    width: 0.8,
                  ),
                ),
              ),
              child: BlocBuilder<LocaleBloc, LocaleState>(
                builder: (context, localeState) {
                  final currentCode = localeState.locale.languageCode;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorderDivider : AppColors.borderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: AppLanguage.supported.any((l) => l.code == currentCode)
                            ? currentCode
                            : 'ar',
                        isExpanded: true,
                        isDense: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              size: 20,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor:
                                isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                            items: AppLanguage.supported.map((lang) {
                              final isSelected = lang.code == currentCode;
                              return DropdownMenuItem<String>(
                                value: lang.code,
                                child: Row(
                                  children: [
                                    CountryFlagSvg.fromLanguageCode(
                                      lang.code,
                                      width: 20,
                                      height: 15,
                                      borderRadius: 2.5,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      lang.nativeName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected
                                            ? (isDark
                                                ? AppColors.darkPrimaryBlue
                                                : AppColors.primaryBlue)
                                            : (isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '(${lang.translationKey.i18n()})',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextTertiary
                                              : AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: isDark
                                            ? AppColors.darkPrimaryBlue
                                            : AppColors.primaryBlue,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newCode) {
                              if (newCode != null && newCode != currentCode) {
                                context.read<LocaleBloc>().add(
                                      ChangeLocale(Locale(newCode)),
                                    );
                              }
                            },
                          ),
                        ),
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateTickerItem({
    required Widget symbolWidget,
    required String prefixNumber,
    required String valueText,
    required bool isDark,
  }) {
    final primaryColor = isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            symbolWidget,
            const SizedBox(width: 3),
            Text(
              prefixNumber,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          valueText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatorTickerItem({
    required BuildContext context,
    required String activeCurrency,
    required bool isDark,
  }) {
    final primaryColor = isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final isArabic = context.isArabic;
    final activePrefix = isArabic ? 'النشطة: ' : 'Active: ';

    Widget activeBadge;
    if (activeCurrency == AppConstants.currencySar) {
      activeBadge = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(activePrefix, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryColor)),
          SaudiRiyalIcon(width: 10, height: 10, color: secondaryColor),
        ],
      );
    } else if (activeCurrency == AppConstants.currencyUsd) {
      activeBadge = Text(
        '$activePrefix\$',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryColor),
      );
    } else {
      activeBadge = Text(
        '$activePrefix${isArabic ? AppConstants.yerSymbol : 'YER'}',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: secondaryColor),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calculate_rounded, size: 13, color: primaryColor),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                isArabic ? 'حاسبة الصرف' : 'Converter',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        activeBadge,
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showQuickCurrencyConverter(BuildContext context) {
    showAppModalSheet(
      context: context,
      title: 'converter_title'.i18n(),
      subtitle: 'converter_subtitle'.i18n(),
      child: const _QuickCurrencyConverterSheet(),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const ForwardChevron(size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCurrencyConverterSheet extends StatefulWidget {
  const _QuickCurrencyConverterSheet();

  @override
  State<_QuickCurrencyConverterSheet> createState() => _QuickCurrencyConverterSheetState();
}

class _QuickCurrencyConverterSheetState extends State<_QuickCurrencyConverterSheet> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  String _sourceCurrency = AppConstants.currencySar;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService.instance;
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final double sarVal = currencyService.convert(amount: amount, fromCurrency: _sourceCurrency, toCurrency: AppConstants.currencySar);
    final double usdVal = currencyService.convert(amount: amount, fromCurrency: _sourceCurrency, toCurrency: AppConstants.currencyUsd);
    final double yerVal = currencyService.convert(amount: amount, fromCurrency: _sourceCurrency, toCurrency: AppConstants.currencyYer);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // حقل إدخال المبلغ والعملة
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                label: 'converter_amount_hint'.i18n(),
                hint: '100',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppDropdownField<String>(
                label: 'converter_currency'.i18n(),
                value: _sourceCurrency,
                items: [
                  DropdownMenuItem(
                    value: AppConstants.currencySar,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SaudiRiyalIcon(width: 14, height: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'currency_sar'.i18n(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.currencyUsd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('\$ ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Flexible(
                          child: Text(
                            'currency_usd'.i18n(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.currencyYer,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${AppConstants.yerSymbol} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Flexible(
                          child: Text(
                            'currency_yer'.i18n(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sourceCurrency = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // بطاقات النتائج المحولة
        _buildResultCard(
          title: 'converter_equiv_sar'.i18n(),
          amountWidget: CurrencyPriceDisplay(
            amount: sarVal,
            currency: AppConstants.currencySar,
            decimalDigits: 2,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _sourceCurrency != AppConstants.currencySar ? AppColors.primaryGreen : AppColors.textPrimary,
            ),
          ),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primaryGreen,
          isHighlight: _sourceCurrency != AppConstants.currencySar,
        ),
        const SizedBox(height: 8),
        _buildResultCard(
          title: 'converter_equiv_usd'.i18n(),
          amountWidget: CurrencyPriceDisplay(
            amount: usdVal,
            currency: AppConstants.currencyUsd,
            decimalDigits: 2,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _sourceCurrency != AppConstants.currencyUsd ? AppColors.primaryBlue : AppColors.textPrimary,
            ),
          ),
          icon: Icons.attach_money_rounded,
          color: AppColors.primaryBlue,
          isHighlight: _sourceCurrency != AppConstants.currencyUsd,
        ),
        const SizedBox(height: 8),
        _buildResultCard(
          title: 'converter_equiv_yer'.i18n(),
          amountWidget: CurrencyPriceDisplay(
            amount: yerVal,
            currency: AppConstants.currencyYer,
            decimalDigits: 1,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _sourceCurrency != AppConstants.currencyYer ? AppColors.vibrantTeal : AppColors.textPrimary,
            ),
          ),
          icon: Icons.receipt_long_outlined,
          color: AppColors.vibrantTeal,
          isHighlight: _sourceCurrency != AppConstants.currencyYer,
        ),
        const SizedBox(height: 16),

        // زر التوجه للإعدادات لتحديث أسعار الصرف
        AppOutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          icon: Icons.tune_rounded,
          label: 'converter_edit_in_settings'.i18n(),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required String title,
    String? amountText,
    Widget? amountWidget,
    required IconData icon,
    required Color color,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight ? color.withValues(alpha: 0.08) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? color.withValues(alpha: 0.25) : AppColors.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
                color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          if (amountWidget != null)
            amountWidget
          else
            Text(
              amountText ?? '',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isHighlight ? color : AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
