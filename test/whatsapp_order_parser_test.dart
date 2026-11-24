import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/features/orders/domain/whatsapp_order_parser.dart';
import 'package:mosaed/features/whatsapp/domain/whatsapp_template_engine.dart';
import 'package:mosaed/models/product.dart';

void main() {
  late List<Product> sampleCatalog;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    await PreferencesService.instance.setBusinessName('مطبخ أم سارة');
    await PreferencesService.instance.setBusinessPhone('771234567');

    LocalizationHelper.setStrings({
      'cat_food_sweets': 'مأكولات وحلويات',
      'cat_perfume_bakhoor': 'بخور وعطور',
      'products_catalog_title': 'كتالوج المنتجات',
      'products_empty_title': 'لا توجد منتجات متاحة حالياً',
      'business_phone_label': 'جوال التواصل',
      'yer': 'ر.ي',
    }, 'ar');

    sampleCatalog = [
      Product(
        id: 'p_mamoul_short',
        name: 'معمول',
        category: 'cat_food_sweets',
        unit: 'علبة',
        sellPrice: 2500,
      ),
      Product(
        id: 'p_mamoul_dates',
        name: 'معمول بالتمر',
        category: 'cat_food_sweets',
        unit: 'علبة',
        sellPrice: 3500,
      ),
      Product(
        id: 'p_bakhoor',
        name: 'بخور ملكي',
        category: 'cat_perfume_bakhoor',
        unit: 'تولة',
        sellPrice: 5000,
      ),
      Product(
        id: 'p_kunafa',
        name: 'كنافة بالقشطة',
        category: 'cat_food_sweets',
        unit: 'صينية',
        sellPrice: 6000,
      ),
      Product(
        id: 'p_rice',
        name: 'أرز بخاري',
        category: 'cat_food_sweets',
        unit: 'صحن',
        sellPrice: 4000,
      ),
      Product(
        id: 'p_halwa',
        name: 'حلوى عمانية',
        category: 'cat_food_sweets',
        unit: 'علبة',
        sellPrice: 4500,
      ),
      Product(
        id: 'p_cake_en',
        name: 'Chocolate Cake',
        category: 'cat_food_sweets',
        unit: 'box',
        sellPrice: 55,
        currency: AppConstants.currencySar,
      ),
      Product(
        id: 'p_honey_en',
        name: 'Honey Box',
        category: 'cat_food_sweets',
        unit: 'jar',
        sellPrice: 90,
        currency: AppConstants.currencySar,
      ),
    ];
  });

  group('WhatsAppOrderParser — Structured Arabic Orders', () {
    test('parses structured Arabic order with Arabic-Indic digits (٠٥ / ٢), address, delivery & notes', () {
      const msg = '''
للطلب السريع، انسخ وعبّئ النموذج التالي وأرسله لنا:
الاسم: أم عبدالله
الجوال: ٠٥٥١٢٣٤٥٦٧
الطلب والكمية:
٢ معمول بالتمر
بخور ملكي × ٣
الحي أو الاستلام: حي النرجس - جوار المسجد
ملاحظات: بدون مكسرات لو سمحتي
''';

      final parsed = WhatsAppOrderParser.parse(msg, sampleCatalog);

      expect(parsed.isEmpty, isFalse);
      expect(parsed.customerName, 'أم عبدالله');
      expect(parsed.customerPhone, '0551234567');
      expect(parsed.deliveryAddress, 'حي النرجس - جوار المسجد');
      expect(parsed.deliveryType, AppConstants.deliveryDelivery);
      expect(parsed.rawNotes, 'بدون مكسرات لو سمحتي');
      expect(parsed.matchedItems.length, 2);
      expect(parsed.matchedItems[0].product.id, 'p_mamoul_dates');
      expect(parsed.matchedItems[0].quantity, 2);
      expect(parsed.matchedItems[1].product.id, 'p_bakhoor');
      expect(parsed.matchedItems[1].quantity, 3);
    });

    test('parses structured Arabic order with Yemeni Arabic-Indic digits (٧٧), عدد N syntax & pickup', () {
      const msg = '''
العميل: محمد علي
رقم الجوال: ٧٧١٢٣٤٥٦٧
الطلب: معمول بالتمر عدد ٤، معمول × ٢
الحي أو الاستلام: استلام من المحل
''';

      final parsed = WhatsAppOrderParser.parse(msg, sampleCatalog);

      expect(parsed.customerName, 'محمد علي');
      expect(parsed.customerPhone, '771234567');
      expect(parsed.deliveryType, AppConstants.deliveryPickup);
      expect(parsed.deliveryAddress, isNull);
      expect(parsed.matchedItems.length, 2);
      expect(parsed.matchedItems[0].product.id, 'p_mamoul_dates');
      expect(parsed.matchedItems[0].quantity, 4);
      expect(parsed.matchedItems[1].product.id, 'p_mamoul_short');
      expect(parsed.matchedItems[1].quantity, 2);
    });
  });

  group('WhatsAppOrderParser — Unstructured Casual Arabic Orders', () {
    test('parses casual Arabic WhatsApp message with phone, delivery neighborhood & multiple items', () {
      const msg =
          'السلام عليكم ابي 3 معمول بالتمر و 2 بخور ملكي جوالي 771234567 توصيل حي حدة';

      final parsed = WhatsAppOrderParser.parse(msg, sampleCatalog);

      expect(parsed.customerPhone, '771234567');
      expect(parsed.deliveryType, AppConstants.deliveryDelivery);
      expect(parsed.deliveryAddress, 'حي حدة');
      expect(parsed.matchedItems.length, 2);
      expect(parsed.matchedItems[0].product.id, 'p_mamoul_dates');
      expect(parsed.matchedItems[0].quantity, 3);
      expect(parsed.matchedItems[1].product.id, 'p_bakhoor');
      expect(parsed.matchedItems[1].quantity, 2);
    });

    test('handles Arabic normalization (أ/إ/آ -> ا, ة -> ه, ى -> ي), Arabic number words & casual pickup', () {
      const msg =
          'مرحبا ابغى حبتين كنافه بالقشطه وواحد ارز بخاري و ٣ حلوي عمانيه باجي اخذها بنفسي رقمي ٠٧٧١٢٣٤٥٦٧';

      final parsed = WhatsAppOrderParser.parse(msg, sampleCatalog);

      expect(parsed.customerPhone, '0771234567');
      expect(parsed.deliveryType, AppConstants.deliveryPickup);
      expect(parsed.matchedItems.length, 3);
      expect(parsed.matchedItems[0].product.id, 'p_kunafa');
      expect(parsed.matchedItems[0].quantity, 2);
      expect(parsed.matchedItems[1].product.id, 'p_rice');
      expect(parsed.matchedItems[1].quantity, 1);
      expect(parsed.matchedItems[2].product.id, 'p_halwa');
      expect(parsed.matchedItems[2].quantity, 3);
    });

    test('does not mistake numbered list prefixes or prices for quantities', () {
      const msg = '''
1. *معمول بالتمر* × 4
2. *بخور ملكي* — 5000 ر.ي
''';

      final parsed = WhatsAppOrderParser.parse(msg, sampleCatalog);

      expect(parsed.matchedItems.length, 2);
      expect(parsed.matchedItems[0].product.id, 'p_mamoul_dates');
      expect(parsed.matchedItems[0].quantity, 4);
      expect(parsed.matchedItems[1].product.id, 'p_bakhoor');
      expect(parsed.matchedItems[1].quantity, 1);
    });
  });

  group('WhatsAppOrderParser — English & International Orders', () {
    test('parses structured English order with international Gulf phone and delivery address', () {
      const msg = '''
Name: Sarah Ahmed
Phone: +971 50 123 4567
Order: 2 chocolate cake, honey box x 3
Address: Downtown Dubai, Blvd 12
Notes: Call on arrival
''';

      final parsed = WhatsAppOrderParser.parse(msg, sampleCatalog);

      expect(parsed.customerName, 'Sarah Ahmed');
      expect(parsed.customerPhone, '+971501234567');
      expect(parsed.deliveryAddress, 'Downtown Dubai, Blvd 12');
      expect(parsed.deliveryType, AppConstants.deliveryDelivery);
      expect(parsed.rawNotes, 'Call on arrival');
      expect(parsed.matchedItems.length, 2);
      expect(parsed.matchedItems[0].product.id, 'p_cake_en');
      expect(parsed.matchedItems[0].quantity, 2);
      expect(parsed.matchedItems[1].product.id, 'p_honey_en');
      expect(parsed.matchedItems[1].quantity, 3);
    });

    test('parses casual English pickup order with +967 phone', () {
      const msg =
          'Hi! I want 3 Chocolate Cake for pickup please. Phone +967 771 234 567';

      final parsed = WhatsAppOrderParser.parse(msg, sampleCatalog);

      expect(parsed.customerPhone, '+967771234567');
      expect(parsed.deliveryType, AppConstants.deliveryPickup);
      expect(parsed.deliveryAddress, isNull);
      expect(parsed.matchedItems.length, 1);
      expect(parsed.matchedItems[0].product.id, 'p_cake_en');
      expect(parsed.matchedItems[0].quantity, 3);
    });
  });

  group('WhatsAppOrderParser — Empty, Noise & Edge-Case Safety', () {
    test('returns empty result for blank or whitespace-only messages', () {
      final empty1 = WhatsAppOrderParser.parse('', sampleCatalog);
      final empty2 = WhatsAppOrderParser.parse('   \n\t  ', sampleCatalog);

      expect(empty1.isEmpty, isTrue);
      expect(empty1.matchedItems, isEmpty);
      expect(empty2.isEmpty, isTrue);
      expect(empty2.matchedItems, isEmpty);
    });

    test('handles greeting-only and noise messages without crashing or hallucinating data', () {
      final greeting = WhatsAppOrderParser.parse('السلام عليكم', sampleCatalog);
      expect(greeting.matchedItems, isEmpty);
      expect(greeting.customerPhone, isNull);
      expect(greeting.deliveryType, isNull);
      expect(greeting.rawNotes, isNull);

      final dateNoise = WhatsAppOrderParser.parse(
        'هل يوجد توصيل بتاريخ 2026-11-24؟',
        sampleCatalog,
      );
      expect(dateNoise.customerPhone, isNull);
      expect(dateNoise.deliveryType, AppConstants.deliveryDelivery);
      expect(dateNoise.matchedItems, isEmpty);

      final emptyCatalogResult = WhatsAppOrderParser.parse(
        'ابي 3 معمول جوالي 771234567',
        const [],
      );
      expect(emptyCatalogResult.customerPhone, '771234567');
      expect(emptyCatalogResult.matchedItems, isEmpty);
    });
  });

  group('WhatsAppTemplateEngine — Enhanced Catalog, Supplier Restock & Shopping List', () {
    test('buildCategorizedCatalogText excludes out-of-stock tracked items and appends quick-order footer', () {
      final products = [
        Product(
          id: 'p_avail_untracked',
          name: 'معمول بالتمر',
          category: 'cat_food_sweets',
          unit: 'علبة',
          sellPrice: 3500,
          trackStock: false,
          stockQuantity: 0,
        ),
        Product(
          id: 'p_avail_tracked',
          name: 'بخور ملكي',
          category: 'cat_perfume_bakhoor',
          unit: 'تولة',
          sellPrice: 5000,
          trackStock: true,
          stockQuantity: 5,
        ),
        Product(
          id: 'p_out_of_stock',
          name: 'بسبوسة نافدة',
          category: 'cat_food_sweets',
          unit: 'صينية',
          sellPrice: 4000,
          trackStock: true,
          stockQuantity: 0,
        ),
        Product(
          id: 'p_inactive',
          name: 'صنف موقوف',
          category: 'cat_food_sweets',
          unit: 'حبة',
          sellPrice: 1000,
          isActive: false,
        ),
      ];

      final catalogText = WhatsAppTemplateEngine.buildCategorizedCatalogText(products);

      expect(catalogText, contains('مطبخ أم سارة'));
      expect(catalogText, contains('معمول بالتمر'));
      expect(catalogText, contains('بخور ملكي'));
      expect(catalogText, isNot(contains('بسبوسة نافدة')));
      expect(catalogText, isNot(contains('صنف موقوف')));
      // Quick-order copyable footer
      expect(catalogText, contains('الاسم:'));
      expect(catalogText, contains('الجوال:'));
      expect(catalogText, contains('الطلب والكمية:'));
      expect(catalogText, contains('الحي أو الاستلام:'));

      // Optional mode showing out-of-stock status instead of excluding
      final withStockStatus = WhatsAppTemplateEngine.buildCategorizedCatalogText(
        products,
        excludeOutOfStock: false,
      );
      expect(withStockStatus, contains('بسبوسة نافدة'));
      expect(withStockStatus, contains('نفد المخزون'));
    });

    test('buildSupplierRestockMessage formats supplier greeting, items and business name cleanly', () {
      final msg = WhatsAppTemplateEngine.buildSupplierRestockMessage(
        supplierName: 'مؤسسة الخير للجملة',
        itemLines: ['دقيق فاخر — 5 كيس', 'سمن بلدي — 2 تنكة'],
        businessName: 'معمل الحلويات',
      );

      expect(msg, contains('*معمل الحلويات*'));
      expect(msg, contains('*مؤسسة الخير للجملة*'));
      expect(msg, contains('1. دقيق فاخر — 5 كيس'));
      expect(msg, contains('2. سمن بلدي — 2 تنكة'));
      expect(msg, contains('771234567'));
    });

    test('buildShoppingListMessage formats grouped daily raw-materials shopping list with date', () {
      final msg = WhatsAppTemplateEngine.buildShoppingListMessage(
        groupedLines: [
          '*[مؤسسة الخير]*',
          '• دقيق فاخر: 3 كجم',
          '• سكر ناعم: 2 كجم',
        ],
        dateLabel: '2026-11-24',
      );

      expect(msg, contains('*مطبخ أم سارة*'));
      expect(msg, contains('قائمة مشتريات المواد الخام'));
      expect(msg, contains('2026-11-24'));
      expect(msg, contains('*[مؤسسة الخير]*'));
      expect(msg, contains('• دقيق فاخر: 3 كجم'));
    });
  });
}
