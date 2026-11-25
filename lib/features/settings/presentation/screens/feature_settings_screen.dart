import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/app_feature_flags.dart';
import '../../../../core/business/business_mode_cubit.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// شاشة اختيار الدور (وضع العمل المبسّط) وتخصيص الميزات الظاهرة لتقليل الزحمة والتعقيد
class FeatureSettingsScreen extends StatefulWidget {
  const FeatureSettingsScreen({super.key});

  @override
  State<FeatureSettingsScreen> createState() => _FeatureSettingsScreenState();
}

class _FeatureSettingsScreenState extends State<FeatureSettingsScreen> {
  final _prefs = PreferencesService.instance;

  BusinessModeCubit? _maybeCubit() {
    try {
      return context.read<BusinessModeCubit>();
    } catch (_) {
      return null;
    }
  }

  String _currentMode(BuildContext context) {
    try {
      return context.watch<BusinessModeCubit>().state.businessMode;
    } catch (_) {
      return _prefs.getBusinessMode();
    }
  }

  AppFeatureFlags _currentFeatures(BuildContext context) {
    try {
      return context.watch<BusinessModeCubit>().state.features;
    } catch (_) {
      return _prefs.getFeatureFlags();
    }
  }

  bool _isMultiCurrency(BuildContext context) {
    try {
      return context.watch<BusinessModeCubit>().state.multiCurrencyEnabled;
    } catch (_) {
      return _prefs.isMultiCurrencyEnabled();
    }
  }

  Future<void> _selectRole(String mode) async {
    final cubit = _maybeCubit();
    if (cubit != null) {
      await cubit.applyRolePreset(mode);
    } else {
      final isTrade = mode == AppConstants.businessModeTradeLogistics;
      await _prefs.setBusinessMode(mode, resetFeatureOverrides: true);
      await _prefs.setMultiCurrencyEnabled(isTrade);
      DataSyncBus.instance.notify(DataDomain.businessMode);
    }
    if (!mounted) return;
    setState(() {});
    AppToast.showSuccess(
      context,
      'role_preset_applied_toast'.trParams({
        'role': AppConstants.getBusinessModeLabel(mode),
      }),
    );
  }

  Future<void> _toggleFeature(String featureKey, bool value) async {
    final cubit = _maybeCubit();
    if (cubit != null) {
      await cubit.toggleFeature(featureKey, value);
    } else {
      await _prefs.setFeatureOverride(featureKey, value);
      DataSyncBus.instance.notify(DataDomain.businessMode);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMultiCurrency(bool value) async {
    final cubit = _maybeCubit();
    if (cubit != null) {
      await cubit.updateProfile(multiCurrencyEnabled: value);
    } else {
      await _prefs.setMultiCurrencyEnabled(value);
      DataSyncBus.instance.notify(DataDomain.businessMode);
    }
    if (mounted) setState(() {});
  }

  Future<void> _resetDefaults() async {
    final cubit = _maybeCubit();
    if (cubit != null) {
      await cubit.resetFeaturesToRoleDefaults();
    } else {
      await _prefs.clearFeatureOverrides();
      DataSyncBus.instance.notify(DataDomain.businessMode);
    }
    if (!mounted) return;
    setState(() {});
    AppToast.showSuccess(context, 'features_reset_done_toast'.i18n());
  }

  IconData _iconForMode(String mode) {
    switch (mode) {
      case AppConstants.businessModeSimpleSeller:
        return Icons.sell_outlined;
      case AppConstants.businessModeArtisanCraft:
        return Icons.handyman_outlined;
      case AppConstants.businessModeRetailShop:
        return Icons.store_mall_directory_outlined;
      case AppConstants.businessModeTradeLogistics:
        return Icons.local_shipping_outlined;
      case AppConstants.businessModeProductiveFamily:
      default:
        return Icons.home_work_outlined;
    }
  }

  Color _colorForMode(String mode) {
    switch (mode) {
      case AppConstants.businessModeSimpleSeller:
        return AppColors.primaryGreen;
      case AppConstants.businessModeArtisanCraft:
        return const Color(0xFF7C3AED);
      case AppConstants.businessModeRetailShop:
        return AppColors.vibrantTeal;
      case AppConstants.businessModeTradeLogistics:
        return AppColors.primaryBlue;
      case AppConstants.businessModeProductiveFamily:
      default:
        return AppColors.statusWarning;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final currentMode = _currentMode(context);
    final features = _currentFeatures(context);
    final multiCurrency = _isMultiCurrency(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('feature_settings_title'.i18n()),
        actions: [
          TextButton.icon(
            onPressed: _resetDefaults,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text('features_reset_btn'.i18n()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ترويسة توضيحية لفكرة التبسيط وإخفاء التعقيد
          AppCard(
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.25),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'feature_settings_intro'.i18n(),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text(
            'feature_roles_section_title'.i18n(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'feature_roles_section_sub'.i18n(),
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 10),

          ...AppConstants.allBusinessModes.map((mode) {
            final isSelected = currentMode == mode;
            final accent = _colorForMode(mode);
            final presetCount =
                AppFeatureFlags.defaultsForMode(mode).enabledCount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => _selectRole(mode),
                backgroundColor: isSelected
                    ? accent.withValues(alpha: 0.08)
                    : null,
                border: Border.all(
                  color: isSelected ? accent : context.borderSubtle,
                  width: isSelected ? 1.6 : 0.8,
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_iconForMode(mode), color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                AppConstants.getBusinessModeLabel(mode),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? accent
                                      : context.textPrimary,
                                ),
                              ),
                              AppBadge(
                                label: 'role_features_count_fmt'.trParams({
                                  'count': '$presetCount',
                                }),
                                color: accent,
                                fontSize: 10,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppConstants.getBusinessModeDescription(mode),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? accent : context.textTertiary,
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          Text(
            'feature_toggles_section_title'.i18n(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'feature_toggles_section_sub'.i18n(),
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 10),

          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                AppSwitchTile(
                  title: 'feature_manufacturing_title'.i18n(),
                  subtitle: 'feature_manufacturing_sub'.i18n(),
                  value: features.manufacturing,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keyManufacturing, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'feature_daily_prep_title'.i18n(),
                  subtitle: 'feature_daily_prep_sub'.i18n(),
                  value: features.dailyPrep,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keyDailyPrep, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'feature_curing_waste_title'.i18n(),
                  subtitle: 'feature_curing_waste_sub'.i18n(),
                  value: features.curingWaste,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keyCuringWaste, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'feature_variants_bundles_title'.i18n(),
                  subtitle: 'feature_variants_bundles_sub'.i18n(),
                  value: features.variantsBundles,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keyVariantsBundles, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'feature_seasonal_deposit_title'.i18n(),
                  subtitle: 'feature_seasonal_deposit_sub'.i18n(),
                  value: features.seasonalDeposit,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keySeasonalDeposit, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'feature_suppliers_title'.i18n(),
                  subtitle: 'feature_suppliers_sub'.i18n(),
                  value: features.suppliers,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keySuppliers, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'feature_couriers_title'.i18n(),
                  subtitle: 'feature_couriers_sub'.i18n(),
                  value: features.couriers,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keyCouriers, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'feature_shipments_title'.i18n(),
                  subtitle: 'feature_shipments_sub'.i18n(),
                  value: features.shipments,
                  onChanged: (v) =>
                      _toggleFeature(AppFeatureFlags.keyShipments, v),
                ),
                const Divider(height: 1),
                AppSwitchTile(
                  title: 'wizard_multi_currency_toggle'.i18n(),
                  subtitle: 'wizard_multi_currency_hint'.i18n(),
                  value: multiCurrency,
                  onChanged: _toggleMultiCurrency,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
