import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/core/widgets/business_drawer.dart';
import 'package:mosaed/core/widgets/saudi_riyal_icon.dart';
import 'package:mosaed/core/widgets/saudi_riyal_text.dart';
import 'package:mosaed/features/printing/models/print_options.dart';
import 'package:mosaed/features/printing/services/pdf_invoice_generator.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    SharedPreferences.setMockInitialValues({
      'app_onboarding_completed': true,
      'app_business_mode': AppConstants.businessModeTradeLogistics,
      'app_business_name': 'متجر النور',
      'app_default_currency': AppConstants.currencySar,
      'app_multi_currency_enabled': true,
      'app_locale_code': 'ar',
      'app_arabic_dialect': ArabicDialect.standardId,
    });
    await PreferencesService.instance.init();

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 13,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
    await LocalizationHelper.load('ar');
  });

  tearDownAll(() async {
    AppDatabase.setTestDatabase(null);
    await db.close();
  });

  group('Saudi Riyal Symbol (U+20C1) Global Font & Inline SVG Rendering', () {
    test('Bundled SaudiRiyalSymbol.ttf parses cleanly and maps U+20C1 for PDF & UI', () async {
      final fontFile = File('assets/fonts/SaudiRiyalSymbol.ttf');
      expect(fontFile.existsSync(), isTrue);

      final bytes = await rootBundle.load('assets/fonts/SaudiRiyalSymbol.ttf');
      expect(bytes.lengthInBytes, greaterThan(500));

      final pdfFont = pw.Font.ttf(bytes);
      expect(pdfFont, isA<pw.TtfFont>());
      final pdfDoc = PdfDocument();
      final builtFont = (pdfFont as pw.TtfFont).buildFont(pdfDoc) as PdfTtfFont;
      expect(builtFont.isRuneSupported(0x20C1), isTrue);
      expect(builtFont.font.charToGlyphIndexMap.containsKey(0x20C1), isTrue);
    });

    test('PdfInvoiceGenerator renders SAR invoice with U+20C1 using fallback font without throwing', () async {
      final order = IndividualOrder(
        id: 'sar-pdf-1',
        orderNumber: 'ORD-SAR-01',
        customerName: 'أحمد صالح',
        currency: AppConstants.currencySar,
        paidAmount: 100.0,
        paymentStatus: AppConstants.paymentPartial,
        items: [
          OrderItem(
            id: 'item-1',
            orderId: 'sar-pdf-1',
            name: 'بخور ملكي',
            quantity: 2,
            costPrice: 50.0,
            sellPrice: 80.0,
            currency: AppConstants.currencySar,
          ),
        ],
      );

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicesPdf(
        orders: [order],
        options: const PrintOptions(
          paperSize: PrintPaperSize.a4,
          columnsPerRow: 1,
        ),
      );
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('AppTheme light & dark themes configure SaudiRiyalSymbol in fontFamilyFallback', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(
          theme.textTheme.bodyMedium?.fontFamilyFallback,
          contains(AppTheme.riyalFontFamily),
        );
        expect(
          theme.textTheme.titleMedium?.fontFamilyFallback,
          contains(AppTheme.riyalFontFamily),
        );
        expect(
          theme.appBarTheme.titleTextStyle?.fontFamilyFallback,
          contains(AppTheme.riyalFontFamily),
        );
        expect(
          theme.dropdownMenuTheme.textStyle?.fontFamilyFallback,
          contains(AppTheme.riyalFontFamily),
        );
        expect(
          theme.chipTheme.labelStyle?.fontFamilyFallback,
          contains(AppTheme.riyalFontFamily),
        );
      }
    });

    testWidgets('SaudiRiyalText renders SaudiRiyalIcon for U+20C1 strings and plain Text otherwise', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                SaudiRiyalText('drawer_exchange_rates'.i18n()),
                SaudiRiyalText(
                  CurrencyService.instance.formatAmount(150, currencyCode: 'SAR'),
                ),
                const SaudiRiyalText('نص بدون رمز عملة'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SaudiRiyalIcon), findsNWidgets(2));
      expect(find.text('نص بدون رمز عملة'), findsOneWidget);
    });

    testWidgets('BusinessDrawer renders Exchange Rates item with inline SaudiRiyalIcon and zero overflow at 360x740', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final localeBloc = LocaleBloc();
      final themeBloc = ThemeBloc();
      final modeCubit = BusinessModeCubit()..loadFromPreferences();
      addTearDown(localeBloc.close);
      addTearDown(themeBloc.close);
      addTearDown(modeCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LocaleBloc>.value(value: localeBloc),
            BlocProvider<ThemeBloc>.value(value: themeBloc),
            BlocProvider<BusinessModeCubit>.value(value: modeCubit),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: BusinessDrawer(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Header SAR rate ticker + active currency pill render SaudiRiyalIcon immediately
      expect(find.byType(SaudiRiyalIcon), findsWidgets);

      // Scroll down to Exchange Rates item inside the drawer ListView
      final exchangeItemFinder = find.byWidgetPredicate(
        (w) =>
            w is SaudiRiyalText && w.data == 'drawer_exchange_rates'.i18n(),
      );
      await tester.scrollUntilVisible(
        exchangeItemFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(exchangeItemFinder, findsOneWidget);
      expect(
        find.descendant(
          of: exchangeItemFinder,
          matching: find.byType(SaudiRiyalIcon),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
