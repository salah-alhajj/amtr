import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/business_mode_cubit.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// بطاقة إعدادات هوية المشروع ونمط العمل (أسر منتجة / متجر منزلي أو تجارة وشحنات)
class BusinessProfileCard extends StatefulWidget {
  const BusinessProfileCard({super.key});

  @override
  State<BusinessProfileCard> createState() => _BusinessProfileCardState();
}

class _BusinessProfileCardState extends State<BusinessProfileCard> {
  final _prefs = PreferencesService.instance;
  late String _businessMode;
  late String _defaultCurrency;
  late bool _multiCurrencyEnabled;
  late int _dailyOrderCap;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _footerController;
  late final TextEditingController _dailyCapController;
  bool _isSaving = false;
  bool _capSavedFeedback = false;

  @override
  void initState() {
    super.initState();
    _businessMode = _prefs.getBusinessMode();
    _defaultCurrency = _prefs.getDefaultCurrency();
    _multiCurrencyEnabled = _prefs.isMultiCurrencyEnabled();
    _dailyOrderCap = _prefs.getDailyOrderCap();
    _nameController = TextEditingController(text: _prefs.getBusinessName());
    _phoneController = TextEditingController(text: _prefs.getBusinessPhone());
    _addressController = TextEditingController(text: _prefs.getBusinessAddress());
    _footerController = TextEditingController(text: _prefs.getInvoiceFooterNote());
    _dailyCapController = TextEditingController(text: _dailyOrderCap.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _footerController.dispose();
    _dailyCapController.dispose();
    super.dispose();
  }

  BusinessModeCubit? _maybeBusinessModeCubit() {
    try {
      return context.read<BusinessModeCubit>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateDailyOrderCap(int newCap) async {
    final normalized = newCap < 0 ? 0 : newCap;
    setState(() {
      _dailyOrderCap = normalized;
      if (_dailyCapController.text != normalized.toString()) {
        _dailyCapController.text = normalized.toString();
        _dailyCapController.selection = TextSelection.collapsed(
          offset: _dailyCapController.text.length,
        );
      }
      _capSavedFeedback = true;
    });
    await _prefs.setDailyOrderCap(normalized);
    DataSyncBus.instance.notify(DataDomain.businessMode);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _capSavedFeedback = false);
      }
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final parsedCap = int.tryParse(_dailyCapController.text.trim()) ?? _dailyOrderCap;
      final normalizedCap = parsedCap < 0 ? 0 : parsedCap;
      _dailyOrderCap = normalizedCap;
      await _prefs.setDailyOrderCap(normalizedCap);

      final cubit = _maybeBusinessModeCubit();
      if (cubit != null) {
        await cubit.updateProfile(
          businessMode: _businessMode,
          businessName: _nameController.text,
          businessPhone: _phoneController.text,
          businessAddress: _addressController.text,
          invoiceFooterNote: _footerController.text,
          defaultCurrency: _defaultCurrency,
          multiCurrencyEnabled: _multiCurrencyEnabled,
        );
      } else {
        await _prefs.setBusinessMode(_businessMode);
        await _prefs.setBusinessName(_nameController.text);
        await _prefs.setBusinessPhone(_phoneController.text);
        await _prefs.setBusinessAddress(_addressController.text);
        await _prefs.setInvoiceFooterNote(_footerController.text);
        await _prefs.setDefaultCurrency(_defaultCurrency);
        await _prefs.setMultiCurrencyEnabled(_multiCurrencyEnabled);
        CurrencyService.instance.setDisplayCurrency(_defaultCurrency);
        DataSyncBus.instance.notify(DataDomain.businessMode);
      }
      if (mounted) {
        AppToast.showSuccess(context, 'business_profile_saved'.i18n());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watchLocaleState();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'business_profile_title'.i18n(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'business_profile_subtitle'.i18n(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'business_mode_label'.i18n(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.allBusinessModes.map((mode) {
              final icon = switch (mode) {
                AppConstants.businessModeSimpleSeller => Icons.sell_outlined,
                AppConstants.businessModeArtisanCraft => Icons.handyman_outlined,
                AppConstants.businessModeRetailShop =>
                  Icons.store_mall_directory_outlined,
                AppConstants.businessModeTradeLogistics =>
                  Icons.local_shipping_outlined,
                _ => Icons.home_work_outlined,
              };
              return _buildModeChip(
                mode: mode,
                icon: icon,
                label: AppConstants.getBusinessModeLabel(mode),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _nameController,
            label: 'business_name_label'.i18n(),
            hint: 'business_name_hint'.i18n(),
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _phoneController,
            label: 'business_phone_label'.i18n(),
            hint: 'business_phone_hint'.i18n(),
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _addressController,
            label: 'business_address_label'.i18n(),
            hint: 'business_address_hint'.i18n(),
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _footerController,
            label: 'business_invoice_footer_label'.i18n(),
            hint: 'business_invoice_footer_hint'.i18n(),
            prefixIcon: Icons.receipt_long_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          AppDropdownField<String>(
            label: 'wizard_default_currency_label'.i18n(),
            value: _defaultCurrency,
            items: [
              DropdownMenuItem(
                value: AppConstants.currencyYer,
                child: Text('currency_yer'.i18n()),
              ),
              DropdownMenuItem(
                value: AppConstants.currencySar,
                child: Text('currency_sar'.i18n()),
              ),
              DropdownMenuItem(
                value: AppConstants.currencyUsd,
                child: Text('currency_usd'.i18n()),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _defaultCurrency = val);
            },
          ),
          const SizedBox(height: 10),
          AppSwitchTile(
            title: 'wizard_multi_currency_toggle'.i18n(),
            subtitle: 'wizard_multi_currency_hint'.i18n(),
            value: _multiCurrencyEnabled,
            onChanged: (val) => setState(() => _multiCurrencyEnabled = val),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderSubtle),
            ),
            child: Row(
              children: [
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
                            'business_daily_order_cap_label'.i18n(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_capSavedFeedback)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 12,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'business_daily_order_cap_saved'.i18n(),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dailyOrderCap == 0
                            ? 'business_daily_order_cap_unlimited'.i18n()
                            : 'business_daily_order_cap_limit_fmt'.trParams({
                                'cap': _dailyOrderCap.toString(),
                              }),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCapStepButton(
                      icon: Icons.remove_rounded,
                      onPressed: _dailyOrderCap > 0
                          ? () => _updateDailyOrderCap(_dailyOrderCap - 1)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 52,
                      height: 36,
                      child: TextField(
                        controller: _dailyCapController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onSubmitted: (val) {
                          final parsed = int.tryParse(val.trim()) ?? 0;
                          _updateDailyOrderCap(parsed);
                        },
                        onChanged: (val) {
                          final parsed = int.tryParse(val.trim());
                          if (parsed != null && parsed != _dailyOrderCap) {
                            _updateDailyOrderCap(parsed);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildCapStepButton(
                      icon: Icons.add_rounded,
                      onPressed: () => _updateDailyOrderCap(_dailyOrderCap + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppPrimaryButton(
            onPressed: _isSaving ? null : _saveProfile,
            isLoading: _isSaving,
            icon: Icons.save_outlined,
            label: 'common_save'.i18n(),
            backgroundColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildCapStepButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 34,
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildModeChip({
    required String mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _businessMode == mode;
    return InkWell(
      onTap: () => setState(() => _businessMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.12)
              : context.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : context.borderSubtle,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primaryGreen : context.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryGreen : context.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
