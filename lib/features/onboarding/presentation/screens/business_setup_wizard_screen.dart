import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/business_mode_cubit.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../navigation/main_navigation_shell.dart';

/// معالج التهيئة السريعة من 3 خطوات لضبط نوع المشروع والهوية والعملة
class BusinessSetupWizardScreen extends StatefulWidget {
  const BusinessSetupWizardScreen({super.key});

  @override
  State<BusinessSetupWizardScreen> createState() =>
      _BusinessSetupWizardScreenState();
}

class _BusinessSetupWizardScreenState extends State<BusinessSetupWizardScreen> {
  int _currentStep = 0;
  String _selectedMode = AppConstants.businessModeProductiveFamily;
  String _selectedCurrency = AppConstants.currencyYer;
  bool _multiCurrencyEnabled = false;
  bool _multiCurrencyTouched = false;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefs = PreferencesService.instance;
    _selectedMode = prefs.getBusinessMode();
    _selectedCurrency = prefs.getDefaultCurrency();
    _multiCurrencyEnabled = prefs.isMultiCurrencyEnabled();
    _nameController.text = prefs.getBusinessName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectMode(String mode) {
    setState(() {
      _selectedMode = mode;
      if (!_multiCurrencyTouched) {
        _multiCurrencyEnabled =
            mode == AppConstants.businessModeTradeLogistics;
      }
    });
  }

  BusinessModeCubit? _maybeBusinessModeCubit() {
    try {
      return context.read<BusinessModeCubit>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _finishSetup() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final cubit = _maybeBusinessModeCubit();
      final trimmedName = _nameController.text.trim();

      if (cubit != null) {
        await cubit.updateProfile(
          businessMode: _selectedMode,
          businessName: trimmedName,
          defaultCurrency: _selectedCurrency,
          multiCurrencyEnabled: _multiCurrencyEnabled,
        );
      } else {
        final prefs = PreferencesService.instance;
        await prefs.setBusinessMode(_selectedMode);
        await prefs.setBusinessName(trimmedName);
        await prefs.setDefaultCurrency(_selectedCurrency);
        await prefs.setMultiCurrencyEnabled(_multiCurrencyEnabled);
        CurrencyService.instance.setDisplayCurrency(_selectedCurrency);
        DataSyncBus.instance.notify(DataDomain.businessMode);
      }

      await PreferencesService.instance.setOnboardingCompleted(true);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finishSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkScaffoldBackground
          : AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_currentStep > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: _previousStep,
                          tooltip: 'common_back'.i18n(),
                        )
                      else
                        const AppLogo(size: 36, borderRadius: 10),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'wizard_step_counter'.trParams({
                            'current': '${_currentStep + 1}',
                            'total': '3',
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(3, (index) {
                      final active = index <= _currentStep;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsetsDirectional.only(
                            end: index < 2 ? 6 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryBlue
                                : (isDark
                                      ? AppColors.darkBorderDivider
                                      : AppColors.borderDivider),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildStepContent(isDark),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: AppPrimaryButton(
                onPressed: _isSaving ? null : _nextStep,
                isLoading: _isSaving,
                icon: _currentStep == 2 ? Icons.rocket_launch_rounded : null,
                trailingIcon: _currentStep < 2
                    ? Icons.arrow_forward_rounded
                    : null,
                label: _currentStep == 2
                    ? 'wizard_start_btn'.i18n()
                    : 'onboarding_next'.i18n(),
                backgroundColor: _currentStep == 2
                    ? AppColors.primaryGreen
                    : AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(isDark);
      case 1:
        return _buildStep2(isDark);
      case 2:
      default:
        return _buildStep3(isDark);
    }
  }

  Widget _buildStep1(bool isDark) {
    return Column(
      key: const ValueKey('wizard_step_1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'wizard_step1_title'.i18n(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'wizard_step1_subtitle'.i18n(),
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        _buildModeOptionCard(
          mode: AppConstants.businessModeSimpleSeller,
          icon: Icons.sell_outlined,
          title: 'business_mode_simple_seller'.i18n(),
          description: 'role_simple_seller_desc'.i18n(),
          accentColor: AppColors.primaryGreen,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildModeOptionCard(
          mode: AppConstants.businessModeProductiveFamily,
          icon: Icons.home_work_rounded,
          title: 'business_mode_family'.i18n(),
          description: 'wizard_family_desc'.i18n(),
          accentColor: AppColors.statusWarning,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildModeOptionCard(
          mode: AppConstants.businessModeArtisanCraft,
          icon: Icons.handyman_outlined,
          title: 'business_mode_artisan'.i18n(),
          description: 'role_artisan_desc'.i18n(),
          accentColor: const Color(0xFF7C3AED),
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildModeOptionCard(
          mode: AppConstants.businessModeRetailShop,
          icon: Icons.store_mall_directory_outlined,
          title: 'business_mode_retail'.i18n(),
          description: 'role_retail_desc'.i18n(),
          accentColor: AppColors.vibrantTeal,
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _buildModeOptionCard(
          mode: AppConstants.businessModeTradeLogistics,
          icon: Icons.local_shipping_rounded,
          title: 'business_mode_trade'.i18n(),
          description: 'wizard_trade_desc'.i18n(),
          accentColor: AppColors.primaryBlue,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildModeOptionCard({
    required String mode,
    required IconData icon,
    required String title,
    required String description,
    required Color accentColor,
    required bool isDark,
  }) {
    final isSelected = _selectedMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectMode(mode),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withValues(alpha: isDark ? 0.16 : 0.08)
                : (isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark
                        ? AppColors.darkBorderDivider
                        : AppColors.borderDivider),
              width: isSelected ? 1.6 : 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? accentColor
                            : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isSelected
                    ? accentColor
                    : (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2(bool isDark) {
    return Column(
      key: const ValueKey('wizard_step_2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'wizard_step2_title'.i18n(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'wizard_step2_subtitle'.i18n(),
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _nameController,
                label: 'business_name_label'.i18n(),
                hint: 'business_name_hint'.i18n(),
                prefixIcon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 18),
              Text(
                'wizard_default_currency_label'.i18n(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildCurrencyChip(
                    code: AppConstants.currencyYer,
                    label: 'currency_yer'.i18n(),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCurrencyChip(
                    code: AppConstants.currencySar,
                    label: 'currency_sar'.i18n(),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildCurrencyChip(
                    code: AppConstants.currencyUsd,
                    label: 'currency_usd'.i18n(),
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppSwitchTile(
                title: 'wizard_multi_currency_toggle'.i18n(),
                subtitle: 'wizard_multi_currency_hint'.i18n(),
                value: _multiCurrencyEnabled,
                onChanged: (val) {
                  setState(() {
                    _multiCurrencyEnabled = val;
                    _multiCurrencyTouched = true;
                  });
                },
              ),
              if (context.watch<LocaleBloc>().state.isArabic) ...[
                const SizedBox(height: 16),
                Text(
                  'dialect_section_title'.i18n(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'dialect_section_subtitle'.i18n(),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final activeDialect =
                        context.watch<LocaleBloc>().state.arabicDialect;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ArabicDialect.supported.map((dialect) {
                        final selected = activeDialect == dialect.id;
                        return ChoiceChip(
                          label: Text(
                            dialect.nativeName,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: selected,
                          onSelected: (_) {
                            context.read<LocaleBloc>().add(
                                  ChangeArabicDialect(dialect.id),
                                );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyChip({
    required String code,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedCurrency.toUpperCase() == code.toUpperCase();
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCurrency = code),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryBlue.withValues(alpha: 0.12)
                : (isDark
                      ? AppColors.darkSurfaceMuted
                      : AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryBlue
                  : (isDark
                        ? AppColors.darkBorderSubtle
                        : AppColors.borderSubtle),
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            children: [
              if (code == AppConstants.currencySar)
                SaudiRiyalIcon(
                  width: 16,
                  height: 16,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                )
              else
                Text(
                  code == AppConstants.currencyUsd
                      ? '\$'
                      : AppConstants.yerSymbol.toLowerCase().i18n(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3(bool isDark) {
    final modeLabel = AppConstants.getBusinessModeLabel(_selectedMode);
    final projectName = _nameController.text.trim();

    return Column(
      key: const ValueKey('wizard_step_3'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primaryGreen,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'wizard_step3_title'.i18n(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'wizard_step3_subtitle'.i18n(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSummaryRow(
                icon: Icons.category_outlined,
                label: 'business_mode_label'.i18n(),
                value: modeLabel,
                isDark: isDark,
              ),
              if (projectName.isNotEmpty) ...[
                const Divider(height: 20),
                _buildSummaryRow(
                  icon: Icons.storefront_outlined,
                  label: 'business_name_label'.i18n(),
                  value: projectName,
                  isDark: isDark,
                ),
              ],
              const Divider(height: 20),
              _buildSummaryRow(
                icon: Icons.payments_outlined,
                label: 'wizard_default_currency_label'.i18n(),
                value: AppConstants.getCurrencyName(_selectedCurrency),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
