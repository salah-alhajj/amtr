// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/main.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RetailAssistantApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RetailAssistantApp), findsOneWidget);
    // تفريغ مؤقت فحص القفل التلقائي في مكتبة sqflite_common
    await tester.pump(const Duration(seconds: 10));
  });
}
