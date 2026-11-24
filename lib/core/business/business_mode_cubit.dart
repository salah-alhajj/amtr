import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants.dart';
import '../services/currency_service.dart';
import '../services/data_sync_bus.dart';
import '../services/preferences_service.dart';

/// الحالة التفاعلية لهوية المشروع ونمط العمل والعملة الأساسية
class BusinessModeState {
  final String businessMode;
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String invoiceFooterNote;
  final String defaultCurrency;
  final bool multiCurrencyEnabled;

  const BusinessModeState({
    this.businessMode = AppConstants.businessModeProductiveFamily,
    this.businessName = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.invoiceFooterNote = '',
    this.defaultCurrency = AppConstants.currencyYer,
    this.multiCurrencyEnabled = false,
  });

  bool get isProductiveFamily =>
      businessMode == AppConstants.businessModeProductiveFamily;

  BusinessModeState copyWith({
    String? businessMode,
    String? businessName,
    String? businessPhone,
    String? businessAddress,
    String? invoiceFooterNote,
    String? defaultCurrency,
    bool? multiCurrencyEnabled,
  }) {
    return BusinessModeState(
      businessMode: businessMode ?? this.businessMode,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      businessAddress: businessAddress ?? this.businessAddress,
      invoiceFooterNote: invoiceFooterNote ?? this.invoiceFooterNote,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      multiCurrencyEnabled: multiCurrencyEnabled ?? this.multiCurrencyEnabled,
    );
  }
}

/// متحكم تفاعلي لوضع النشاط التجاري وهوية المشروع
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
  }) async {
    if (businessMode != null) {
      await _prefs.setBusinessMode(businessMode);
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
      ),
    );
    DataSyncBus.instance.notify(DataDomain.businessMode);
  }
}
