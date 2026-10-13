import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/features/dashboard/presentation/widgets/financial_analytics_card.dart';

void main() {
  group('FinancialAnalyticsCard Tests', () {
    setUp(() {
      LocalizationHelper.setStrings({
        'financial_analytics_title': 'Financial Analytics & Indicators',
        'chart_trend': 'Trend',
        'chart_distribution': 'Distribution',
        'day_saturday': 'Sat',
        'day_sunday': 'Sun',
        'day_monday': 'Mon',
        'day_tuesday': 'Tue',
        'day_wednesday': 'Wed',
        'day_thursday': 'Thu',
        'day_today': 'Today',
      }, 'en');
    });

    testWidgets('Renders properly without overflow on constrained width in English', (tester) async {
      // Simulate iPhone / narrow screen width 374.4 width
      tester.view.physicalSize = const Size(374.4, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          home: Scaffold(
            body: SizedBox(
              width: 374.4,
              child: FinancialAnalyticsCard(
                collectedAmount: 5000,
                remainingAmount: 1200,
                debtAmount: 800,
                totalRevenue: 7000,
                activeCurrency: 'SAR',
                weeklySales: [1000, 2000, 1500, 3000, 2500],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FinancialAnalyticsCard), findsOneWidget);
      expect(find.text('Financial Analytics & Indicators'), findsOneWidget);
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Distribution'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
