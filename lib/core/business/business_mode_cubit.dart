import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants.dart';
import '../services/currency_service.dart';
import '../services/data_sync_bus.dart';
import '../services/preferences_service.dart';
import 'app_feature_flags.dart';

/// الحالة التفاعلية لهوية المشروع ونمط العمل والعملة الأساسية وأعلام الميزات
class BusinessModeState {
  final String businessMode;
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String invoiceFooterNote;
  final String defaultCurrency;
  final bool multiCurrencyEnabled;
  final AppFeatureFlags features;

  const BusinessModeState({
    this.businessMode = AppConstants.businessModeProductiveFamily,
    this.businessName = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.invoiceFooterNote = '',
    this.defaultCurrency = AppConstants.currencyYer,
    this.multiCurrencyEnabled = false,
    this.features = const AppFeatureFlags(),
  });

  bool get isProductiveFamily =>
      businessMode != AppConstants.businessModeTradeLogistics;

  BusinessModeState copyWith({
    String? businessMode,
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? invoiceFooterNote,
    String? defaultCurrency,
    bool? multiCurrencyEnabled,
    AppFeatureFlags? features,
  }) {
    return BusinessModeState(
      businessMode: businessMode ?? this.businessMode,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      businessAddress: businessAddress ?? this.businessAddress,
      invoiceFooterNote: invoiceFooterNote ?? this.invoiceFooterNote,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      multiCurrencyEnabled: multiCurrencyEnabled ?? this.multiCurrencyEnabled,
      features: features ?? this.features,
    );
  }
}

/// متحكم تفاعلي لوضع النشاط التجاري وهوية المشروع وإدارة الميزات
class BusinessModeCubit extends Cubit<BusinessModeState> {
  final PreferencesService _prefs;
  final CurrencyService _currencyService;

  BusinessModeCubit({
    PreferencesService? prefs,
    CurrencyService? currencyService,
  })  : _prefs = prefs ?? PreferencesService.instance,
        _currencyService = currencyService ?? CurrencyService.instance,
        super(const BusinessModeState());

  void loadFromPreferences() {
    final defaultCurrency = _prefs.getDefaultCurrency();
    _currencyService.setDisplayCurrency(defaultCurrency);
    emit(
      BusinessModeState(
        businessMode: _prefs.getBusinessMode(),
        businessName: _prefs.getBusinessName(),
        businessPhone: _prefs.getBusinessPhone(),
        businessAddress: _prefs.getBusinessAddress(),
        invoiceFooterNote: _prefs.getInvoiceFooterNote(),
        defaultCurrency: defaultCurrency,
        multiCurrencyEnabled: _prefs.isMultiCurrencyEnabled(),
        features: _prefs.getFeatureFlags(),
      ),
    );
  }

  Future<void> updateProfile({
    String? businessMode,
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? invoiceFooterNote,
    String? defaultCurrency,
    bool? multiCurrencyEnabled,
    bool resetFeatureOverrides = false,
  }) async {
    if (businessMode != null) {
      await _prefs.setBusinessMode(
        businessMode,
        resetFeatureOverrides: resetFeatureOverrides,
      );
    }
    if (businessName != null) {
      await _prefs.setBusinessName(businessName);
    }
    if (businessPhone != null) {
      await _prefs.setBusinessPhone(businessPhone);
    }
    if (businessAddress != null) {
      await _prefs.setBusinessAddress(businessAddress);
    }
    if (invoiceFooterNote != null) {
      await _prefs.setInvoiceFooterNote(invoiceFooterNote);
    }
    if (defaultCurrency != null) {
      await _prefs.setDefaultCurrency(defaultCurrency);
      _currencyService.setDisplayCurrency(defaultCurrency);
    }
    if (multiCurrencyEnabled != null) {
      await _prefs.setMultiCurrencyEnabled(multiCurrencyEnabled);
    }

    emit(
      state.copyWith(
        businessMode: businessMode,
        businessName: businessName?.trim(),
        businessPhone: businessPhone?.trim(),
        businessAddress: businessAddress?.trim(),
        invoiceFooterNote: invoiceFooterNote?.trim(),
        defaultCurrency: defaultCurrency,
        multiCurrencyEnabled: multiCurrencyEnabled,
        features: _prefs.getFeatureFlags(),
      ),
    );
    DataSyncBus.instance.notify(DataDomain.businessMode);
  }

  /// تطبيق قالب دور متكامل مع إعادة ضبط تخصيصات الميزات على افتراضيات الدور
  Future<void> applyRolePreset(String mode) async {
    final isTrade = mode == AppConstants.businessModeTradeLogistics;
    await _prefs.setBusinessMode(mode, resetFeatureOverrides: true);
    await _prefs.setMultiCurrencyEnabled(isTrade);
    emit(
      state.copyWith(
        businessMode: mode,
        multiCurrencyEnabled: isTrade,
        features: _prefs.getFeatureFlags(),
      ),
    );
    DataSyncBus.instance.notify(DataDomain.businessMode);
  }

  /// تفعيل أو إخفاء ميزة محددة يدوياً
  Future<void> toggleFeature(String featureKey, bool enabled) async {
    await _prefs.setFeatureOverride(featureKey, enabled);
    emit(state.copyWith(features: _prefs.getFeatureFlags()));
    DataSyncBus.instance.notify(DataDomain.businessMode);
  }

  /// استعادة الميزات الافتراضية للدور الحالي
  Future<void> resetFeaturesToRoleDefaults() async {
    await _prefs.clearFeatureOverrides();
    emit(state.copyWith(features: _prefs.getFeatureFlags()));
    DataSyncBus.instance.notify(DataDomain.businessMode);
  }
}
