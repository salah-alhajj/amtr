import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../constants.dart';
import '../database/app_database.dart';
import 'data_sync_bus.dart';

/// إحصائيات وسجلات البيانات التجريبية المتوفرة في قاعدة البيانات
class DemoDataStats {
  final int customersCount;
  final int shipmentsCount;
  final int ordersCount;
  final int itemsCount;
  final int suppliersCount;
  final int rawMaterialsCount;
  final int templatesCount;
  final int productsCount;
  final int expensesCount;
  final int paymentsCount;
  final int closingsCount;
  final int extraRecordsCount;

  const DemoDataStats({
    this.customersCount = 0,
    this.shipmentsCount = 0,
    this.ordersCount = 0,
    this.itemsCount = 0,
    this.suppliersCount = 0,
    this.rawMaterialsCount = 0,
    this.templatesCount = 0,
    this.productsCount = 0,
    this.expensesCount = 0,
    this.paymentsCount = 0,
    this.closingsCount = 0,
    this.extraRecordsCount = 0,
  });

  int get totalRecords =>
      customersCount +
      shipmentsCount +
      ordersCount +
      itemsCount +
      suppliersCount +
      rawMaterialsCount +
      templatesCount +
      productsCount +
      expensesCount +
      paymentsCount +
      closingsCount +
      extraRecordsCount;
  bool get hasDemoData => totalRecords > 0;
}

/// خدمة توليد وحذف الداتا التجريبية والتدريبية للنظام
/// تنشئ مئات السجلات الواقعية المستوحاة بالكامل من البيئة والتجارة والمحافظات والأسواق اليمنية
/// (عملاء يمنيون، موردون، مواد خام وقوالب تصنيع، منتجات بيع وشراء وتصنيع، مصاريف دورية ونثريات،
/// فرزات وشركات نقل محلية، طلبات وحركات دفع وإغلاقات يومية)
/// وتتيح إزالتها كلياً بنقرة واحدة دون المساس بأي بيانات حقيقية أخرى.
class DemoDataService {
  static final DemoDataService instance = DemoDataService._init();
  DemoDataService._init();

  Future<int> _countDemo(Database db, String table) async {
    try {
      return Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM $table WHERE id LIKE 'demo_%'",
            ),
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// جلب إحصائيات البيانات التجريبية الحالية في قاعدة البيانات
  Future<DemoDataStats> getDemoDataStats() async {
    final db = await AppDatabase.instance.database;
    final cCount = await _countDemo(db, 'customers');
    final sCount = await _countDemo(db, 'shipments');
    final oCount = await _countDemo(db, 'orders');
    final iCount = await _countDemo(db, 'order_items');
    final supCount = await _countDemo(db, 'suppliers');
    final matCount = await _countDemo(db, 'raw_materials');
    final tplCount = await _countDemo(db, 'manufacturing_templates');
    final prodCount = await _countDemo(db, 'products');
    final expCount = await _countDemo(db, 'expenses');
    final payCount = await _countDemo(db, 'payment_transactions');
    final closeCount = await _countDemo(db, 'daily_closings');
    final tpliCount = await _countDemo(db, 'manufacturing_template_items');
    final ingCount = await _countDemo(db, 'product_ingredients');
    final batchCount = await _countDemo(db, 'production_batches');
    final supTxCount = await _countDemo(db, 'supplier_transactions');
    final courierCount = await _countDemo(db, 'couriers');
    final courierSettleCount = await _countDemo(db, 'courier_settlements');
    final variantsCount = await _countDemo(db, 'product_variants');
    final bundleItemsCount = await _countDemo(db, 'product_bundle_items');
    final wasteLogsCount = await _countDemo(db, 'waste_logs');

    return DemoDataStats(
      customersCount: cCount,
      shipmentsCount: sCount,
      ordersCount: oCount,
      itemsCount: iCount,
      suppliersCount: supCount,
      rawMaterialsCount: matCount,
      templatesCount: tplCount,
      productsCount: prodCount,
      expensesCount: expCount,
      paymentsCount: payCount,
      closingsCount: closeCount,
      extraRecordsCount: tpliCount +
          ingCount +
          batchCount +
          supTxCount +
          courierCount +
          courierSettleCount +
          variantsCount +
          bundleItemsCount +
          wasteLogsCount,
    );
  }

  /// إجمالي عدد السجلات التجريبية الحالية
  Future<int> getDemoDataCount() async =>
      (await getDemoDataStats()).totalRecords;

  /// اسم بديل آمن لحذف كافة البيانات التجريبية
  Future<int> clearDemoData() => removeDemoData();

  void _notifyAllDomains() {
    DataSyncBus.instance.notify(DataDomain.orders);
    DataSyncBus.instance.notify(DataDomain.payments);
    DataSyncBus.instance.notify(DataDomain.expenses);
    DataSyncBus.instance.notify(DataDomain.products);
    DataSyncBus.instance.notify(DataDomain.customers);
    DataSyncBus.instance.notify(DataDomain.suppliers);
    DataSyncBus.instance.notify(DataDomain.materials);
    DataSyncBus.instance.notify(DataDomain.couriers);
  }

  /// حذف كافة البيانات التجريبية من قاعدة البيانات بشكل آمن تماماً
  Future<int> removeDemoData() async {
    final db = await AppDatabase.instance.database;
    int totalDeleted = 0;

    await db.transaction((txn) async {
      // فك ارتباط أي سجلات غير تجريبية كانت مرتبطة بسجلات تجريبية لتفادي أي مراجع معلقة
      await txn.rawUpdate(
        "UPDATE orders SET shipmentId = NULL WHERE shipmentId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE orders SET customerId = NULL WHERE customerId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE order_items SET productId = NULL WHERE productId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE products SET supplierId = NULL WHERE supplierId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE products SET templateId = NULL WHERE templateId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE raw_materials SET supplierId = NULL WHERE supplierId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE expenses SET supplierId = NULL WHERE supplierId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE product_ingredients SET materialId = NULL WHERE materialId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE manufacturing_template_items SET materialId = NULL WHERE materialId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );
      await txn.rawUpdate(
        "UPDATE orders SET courierId = NULL, courierStatus = 'none', courierFee = 0.0, isSettledWithCourier = 0 WHERE courierId LIKE 'demo_%' AND id NOT LIKE 'demo_%'",
      );

      final supplierTxDeleted = await txn.delete(
        'supplier_transactions',
        where: 'id LIKE ? OR supplierId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final courierSettlementsDeleted = await txn.delete(
        'courier_settlements',
        where: 'id LIKE ? OR courierId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final couriersDeleted = await txn.delete(
        'couriers',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final paymentsDeleted = await txn.delete(
        'payment_transactions',
        where: 'id LIKE ? OR orderId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final closingsDeleted = await txn.delete(
        'daily_closings',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final batchesDeleted = await txn.delete(
        'production_batches',
        where: 'id LIKE ? OR productId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final variantsDeleted = await txn.delete(
        'product_variants',
        where: 'id LIKE ? OR productId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final bundleItemsDeleted = await txn.delete(
        'product_bundle_items',
        where: 'id LIKE ? OR bundleProductId LIKE ? OR componentProductId LIKE ?',
        whereArgs: ['demo_%', 'demo_%', 'demo_%'],
      );
      final wasteLogsDeleted = await txn.delete(
        'waste_logs',
        where: 'id LIKE ? OR itemId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final ingredientsDeleted = await txn.delete(
        'product_ingredients',
        where: 'id LIKE ? OR productId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final templateItemsDeleted = await txn.delete(
        'manufacturing_template_items',
        where: 'id LIKE ? OR templateId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final templatesDeleted = await txn.delete(
        'manufacturing_templates',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final materialsDeleted = await txn.delete(
        'raw_materials',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final productsDeleted = await txn.delete(
        'products',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final expensesDeleted = await txn.delete(
        'expenses',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final suppliersDeleted = await txn.delete(
        'suppliers',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final itemsDeleted = await txn.delete(
        'order_items',
        where: 'id LIKE ? OR orderId LIKE ?',
        whereArgs: ['demo_%', 'demo_%'],
      );
      final ordersDeleted = await txn.delete(
        'orders',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final shipmentsDeleted = await txn.delete(
        'shipments',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );
      final customersDeleted = await txn.delete(
        'customers',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
      );

      totalDeleted = supplierTxDeleted +
          courierSettlementsDeleted +
          couriersDeleted +
          paymentsDeleted +
          closingsDeleted +
          batchesDeleted +
          variantsDeleted +
          bundleItemsDeleted +
          wasteLogsDeleted +
          ingredientsDeleted +
          templateItemsDeleted +
          templatesDeleted +
          materialsDeleted +
          productsDeleted +
          expensesDeleted +
          suppliersDeleted +
          itemsDeleted +
          ordersDeleted +
          shipmentsDeleted +
          customersDeleted;
    });

    _notifyAllDomains();
    return totalDeleted;
  }

  /// توليد مئات البيانات التجريبية اليمنية الحقيقية والمترابطة
  Future<DemoDataStats> generateDemoData() async {
    // إزالة أي داتا تجريبية سابقة لتجنب تكرار المعرفات
    await removeDemoData();

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();

    // =========================================================================
    // 1. العملاء اليمنيون الواقعيون بمختلف المحافظات والأسواق (35 عميلاً)
    // =========================================================================
    final customerDefinitions = <Map<String, String?>>[
      {
        'name': 'عبدالكريم محمد المؤيد',
        'phone': '+967 771234567',
        'whatsapp': '+967 771234567',
        'notes': 'تاجر أقمشة ومفارش - سوق الزمر بصنعاء القديمة - سداد عبر الكريمي',
      },
      {
        'name': 'وضاح سالم باحارثة',
        'phone': '+967 711892341',
        'whatsapp': '+967 711892341',
        'notes': 'مؤسسة باحارثة للعسل والبهارات - الشرج المكلا - شحن بري مستمر',
      },
      {
        'name': 'فضل عبدالقوي اليافعي',
        'phone': '+967 733918273',
        'whatsapp': '+967 733918273',
        'notes': 'معرض الأناقة للأزياء والملابس - شارع الشهيد مدرم المعلا عدن',
      },
      {
        'name': 'حمود أحمد الحرازي',
        'phone': '+967 777219843',
        'whatsapp': '+967 777219843',
        'notes': 'محمصة وتجارة البن والمكسرات البلدية - باب اليمن صنعاء',
      },
      {
        'name': 'نبيل صادق العريقي',
        'phone': '+967 734567890',
        'whatsapp': '+967 734567890',
        'notes': 'مركز العريقي للإلكترونيات والهواتف - شارع جمال تعز',
      },
      {
        'name': 'نجوى حميد الصبري',
        'phone': '+967 712345678',
        'whatsapp': '+967 712345678',
        'notes': 'بوتيك لمسات حريرية للعبايات والفساتين - المسبح الأسفل تعز',
      },
      {
        'name': 'أروى علي المطهر',
        'phone': '+967 775566778',
        'whatsapp': '+967 775566778',
        'notes': 'زبونة دورية - مستحضرات تجميل وعطور فرنسية - حي حدة صنعاء',
      },
      {
        'name': 'سمير عمر بارجاء',
        'phone': '+967 718899001',
        'whatsapp': '+967 718899001',
        'notes': 'معرض بارجاء للأجهزة المنزلية والإلكترونيات - السوق العام تريم',
      },
      {
        'name': 'صادق عبدالجليل الشيباني',
        'phone': '+967 773344556',
        'whatsapp': '+967 773344556',
        'notes': 'وكالة الشيباني لمنظومات الطاقة الشمسية والبطاريات - شارع العدين إب',
      },
      {
        'name': 'فؤاد حسن الذبحاني',
        'phone': '+967 735566778',
        'whatsapp': '+967 735566778',
        'notes': 'محل الذبحاني لقطع الغيار والإكسسوارات - ميدان التحرير صنعاء',
      },
      {
        'name': 'عائشة أحمد الأكوع',
        'phone': '+967 779900112',
        'whatsapp': '+967 779900112',
        'notes': 'مستلزمات ضيافة وأطقم سفرة ملكية - حي الروضة صنعاء',
      },
      {
        'name': 'رضوان مسعد الجعشني',
        'phone': '+967 713322110',
        'whatsapp': '+967 713322110',
        'notes': 'متجر أدوات منزلية وقدور جرانيت صحية - مثلث الظهار إب',
      },
      {
        'name': 'عمار يسلم بلعبيد',
        'phone': '+967 731122334',
        'whatsapp': '+967 731122334',
        'notes': 'تجارة العسل الشبواني الجرداني والبخور - الشارع العام عتق شبوة',
      },
      {
        'name': 'سامي مبارك بن كوير',
        'phone': '+967 714433221',
        'whatsapp': '+967 714433221',
        'notes': 'مكتب استيراد وتخليص جمركي - منفذ شحن الحدودي الغيضة المهرة',
      },
      {
        'name': 'عبدالباري قاسم المخلافي',
        'phone': '+967 772233445',
        'whatsapp': '+967 772233445',
        'notes': 'توريد راوترات يمن فورجي ومعدات شبكات - مفرق بير باشا تعز',
      },
      {
        'name': 'منير عبدالله باوزير',
        'phone': '+967 716655443',
        'whatsapp': '+967 716655443',
        'notes': 'فضيات وعسل دوعني وتحف تراثية - سوق الحرفيين سيئون',
      },
      {
        'name': 'إيناس صالح الحيمي',
        'phone': '+967 770112233',
        'whatsapp': '+967 770112233',
        'notes': 'بخور عدني عرائسي وزباد وعناية بالبشرة - بيت بوس صنعاء',
      },
      {
        'name': 'جلال محمد العمري',
        'phone': '+967 737788990',
        'whatsapp': '+967 737788990',
        'notes': 'معاوز بيضانية حياكة ممتازة وملابس - سوق رداع المركزي البيضاء',
      },
      {
        'name': 'عبير أحمد الصعدي',
        'phone': '+967 774455667',
        'whatsapp': '+967 774455667',
        'notes': 'زبيب رازقي ولوز خولاني وبن صافي - سوق الطلح صعدة',
      },
      {
        'name': 'وليد فضل الكازمي',
        'phone': '+967 732233445',
        'whatsapp': '+967 732233445',
        'notes': 'تجارة تجزئة ومواد غذائية - الشارع العام زنجبار أبين',
      },
      {
        'name': 'خديجة عبدالرحمن الماوري',
        'phone': '+967 778811223',
        'whatsapp': '+967 778811223',
        'notes': 'مفارش غرف نوم وستائر تركي - شارع تعز شميلة صنعاء',
      },
      {
        'name': 'ماجد هائل الصنوي',
        'phone': '+967 715544332',
        'whatsapp': '+967 715544332',
        'notes': 'أجهزة تبريد ومكيفات ومراوح شحن - شارع صنعاء الحوك الحديدة',
      },
      {
        'name': 'أنور سعيد الردفاني',
        'phone': '+967 738899001',
        'whatsapp': '+967 738899001',
        'notes': 'منظومات طاقة وأدوات كهربائية - سوق الحوطة لحج',
      },
      {
        'name': 'بلقيس عبده القادري',
        'phone': '+967 776611223',
        'whatsapp': '+967 776611223',
        'notes': 'شيلان صوف وأطقم غمرة صنعاني - مثلث السحول إب',
      },
      {
        'name': 'عبدالحكيم ناصر المرادي',
        'phone': '+967 717788992',
        'whatsapp': '+967 717788992',
        'notes': 'قطع غيار شاحنات ومولدات كهرباء - مجمع الوادي مأرب',
      },
      {
        'name': 'ياسمين حمزة المتوكل',
        'phone': '+967 770099887',
        'whatsapp': '+967 770099887',
        'notes': 'كاميرات مراقبة وأجهزة ذكية - الدائري الغربي جولة سيتي مارت',
      },
      {
        'name': 'مروان علوي السقاف',
        'phone': '+967 736655441',
        'whatsapp': '+967 736655441',
        'notes': 'عطورات شرقية ودهن عود كلمنتان - شارع أروى كريتر عدن',
      },
      {
        'name': 'تهاني عبدالملك الزبيري',
        'phone': '+967 773322114',
        'whatsapp': '+967 773322114',
        'notes': 'جلابيات مطرزة ومصوغات فضية تراثية - شارع بغداد صنعاء',
      },
      {
        'name': 'عادل سالم بلحمر',
        'phone': '+967 719988776',
        'whatsapp': '+967 719988776',
        'notes': 'شحن بحري وبضائع مجففة ومكسرات - حي السحيل الشحر حضرموت',
      },
      {
        'name': 'حنان أحمد الهتار',
        'phone': '+967 776655443',
        'whatsapp': '+967 776655443',
        'notes': 'مستحضرات عناية وأجهزة تصفيف شعر - شارع عمان صنعاء',
      },
      {
        'name': 'بشير محمد الضبيبي',
        'phone': '+967 739988112',
        'whatsapp': '+967 739988112',
        'notes': 'جنابي صيفاني وأحزمة عسيب وحرف يدوية - الجبين ريمة',
      },
      {
        'name': 'ميثاق غالب العديني',
        'phone': '+967 771144778',
        'whatsapp': '+967 771144778',
        'notes': 'أدوات تحضير القهوة والقهوة المختصة - حارة المستشفى العدين إب',
      },
      {
        'name': 'نادية منصور الصلوي',
        'phone': '+967 712211334',
        'whatsapp': '+967 712211334',
        'notes': 'فساتين سهرة وأقمشة شيفون كوري - جولة ديلوكس تعز',
      },
      {
        'name': 'عصام خالد الحاشدي',
        'phone': '+967 775511229',
        'whatsapp': '+967 775511229',
        'notes': 'مقاولات تمديدات وكابلات شبكات - حي الحصبة صنعاء',
      },
      {
        'name': 'ليلى ناصر العولقي',
        'phone': '+967 734499221',
        'whatsapp': '+967 734499221',
        'notes': 'بخور ظفاري وأعشاب طبيعية وزيوت عطرية - بيحان شبوة',
      },
    ];

    // =========================================================================
    // 2. الشحنات المجمعة والفرزات وشركات النقل اليمنية الحقيقية (15 شحنة)
    // =========================================================================
    final shipmentDefinitions = <Map<String, dynamic>>[
      {
        'num': 'SHP-YMN-01',
        'title': 'إرسالية الرياض - منفذ الوديعة البري 14',
        'carrier': 'شركة الرويشان للنقل الدولي السريع',
        'tracking': 'RWS-WAD-44120',
        'cost': 480.0,
        'currency': AppConstants.currencySar,
        'status': AppConstants.shipmentDistribution,
        'daysAgo': 12,
        'expectedDays': 3,
        'deliveredDays': null,
        'notes': 'طرود بضائع قادمة عبر منفذ الوديعة - مكتب الصافية صنعاء للتوزيع',
      },
      {
        'num': 'SHP-YMN-02',
        'title': 'حمولة راحة السريعة VIP 08 - طرود جدة',
        'carrier': 'شركة راحة للنقل البري والخدمات اللوجستية',
        'tracking': 'RAH-JED-55210',
        'cost': 650.0,
        'currency': AppConstants.currencySar,
        'status': AppConstants.shipmentCheckpoint,
        'daysAgo': 7,
        'expectedDays': 4,
        'deliveredDays': null,
        'notes': 'وصلت نقطة الفرز والتفتيش بمنفذ الوديعة بانتظار الانطلاق لصنعاء',
      },
      {
        'num': 'SHP-YMN-03',
        'title': 'كونتينر ميناء الحديدة البحري 03 - ألواح طاقة وأجهزة',
        'carrier': 'البحار للشحن والتخليص الجمركي',
        'tracking': 'BHR-HDD-88174',
        'cost': 1400.0,
        'currency': AppConstants.currencyUsd,
        'status': AppConstants.shipmentDispatched,
        'daysAgo': 20,
        'expectedDays': 10,
        'deliveredDays': null,
        'notes': 'حاوية 40 قدم في المجرى الملاحي متجهة لرصيف ميناء الحديدة',
      },
      {
        'num': 'SHP-YMN-04',
        'title': 'حمولة النجم السريع المباشرة 22 (عدن - صنعاء)',
        'carrier': 'شركة النجم السريع لخدمات الشحن الداخلي',
        'tracking': 'NJM-SAN-33901',
        'cost': 95000.0,
        'currency': AppConstants.currencyYer,
        'status': AppConstants.shipmentDelivered,
        'daysAgo': 28,
        'expectedDays': 25,
        'deliveredDays': 24,
        'notes': 'تم استلام وتوزيع كافة الطرود في فرع شميلة بصنعاء بالكامل',
      },
      {
        'num': 'SHP-YMN-05',
        'title': 'إرسالية منفذ شحن المهرة 05 - مسقط وصلالة',
        'carrier': 'الناقل العماني اليمني المشترك',
        'tracking': 'OMN-MHR-77120',
        'cost': 350.0,
        'currency': AppConstants.currencySar,
        'status': AppConstants.shipmentDistribution,
        'daysAgo': 14,
        'expectedDays': 2,
        'deliveredDays': null,
        'notes': 'بخور وظفاريات ولبان حوجري جاهز للتسليم في الغيضة وعتق',
      },
      {
        'num': 'SHP-YMN-06',
        'title': 'شحنة البراق التجميعية 11 - دبي والشارقة',
        'carrier': 'مؤسسة البراق للترانزيت والشحن الدولي',
        'tracking': 'BRQ-DXB-44092',
        'cost': 520.0,
        'currency': AppConstants.currencySar,
        'status': AppConstants.shipmentCheckpoint,
        'daysAgo': 8,
        'expectedDays': 3,
        'deliveredDays': null,
        'notes': 'أجهزة إلكترونية وهواتف وصلت حوش الفرز الجمركي بعفار',
      },
      {
        'num': 'SHP-YMN-07',
        'title': 'حمولة إكسبريس حضرموت 07 - المكلا وسيئون',
        'carrier': 'إكسبريس حضرموت للشحن والطرود',
        'tracking': 'EXP-HAD-11843',
        'cost': 80000.0,
        'currency': AppConstants.currencyYer,
        'status': AppConstants.shipmentDistribution,
        'daysAgo': 9,
        'expectedDays': 1,
        'deliveredDays': null,
        'notes': 'عسل دوعني أصلي وتمور ومنتجات محلية جاهزة للتوزيع بالصافية',
      },
      {
        'num': 'SHP-YMN-08',
        'title': 'إرسالية الأولى للنقل الدولي 09 - الدمام والخبر',
        'carrier': 'شركة الأولى للنقل البري والشحن',
        'tracking': 'AWL-DMM-66289',
        'cost': 490.0,
        'currency': AppConstants.currencySar,
        'status': AppConstants.shipmentDispatched,
        'daysAgo': 4,
        'expectedDays': 6,
        'deliveredDays': null,
        'notes': 'قطع غيار ولوازم سيارات متجهة إلى منفذ الوديعة ومأرب',
      },
      {
        'num': 'SHP-YMN-09',
        'title': 'شحنة ميناء المعلا للحاويات 01 - كراتين أقمشة وملابس',
        'carrier': 'المحيط للخدمات البحرية والتخليص الجمركي عدن',
        'tracking': 'MHT-ADN-22781',
        'cost': 980.0,
        'currency': AppConstants.currencyUsd,
        'status': AppConstants.shipmentDelivered,
        'daysAgo': 38,
        'expectedDays': 32,
        'deliveredDays': 31,
        'notes': 'تم تفريغ الحاوية وتوزيعها على معارض عدن ولحج',
      },
      {
        'num': 'SHP-YMN-10',
        'title': 'حمولة ابن معمر السريعة 17 - مكة وجدة',
        'carrier': 'مؤسسة ابن معمر للنقل الدولي',
        'tracking': 'BMR-MAK-99432',
        'cost': 580.0,
        'currency': AppConstants.currencySar,
        'status': AppConstants.shipmentCheckpoint,
        'daysAgo': 22,
        'expectedDays': 3,
        'deliveredDays': null,
        'notes': 'وصلت محطة الترانزيت بحزم الجوف متجهة للمقر الرئيسي بصنعاء',
      },
      {
        'num': 'SHP-YMN-11',
        'title': 'إرسالية البريد السريع يمن بوست 04 - مطبوعات ومعدات',
        'carrier': 'الهيئة العامة للبريد والتوفير البريدي (يمن بوست)',
        'tracking': 'YMN-PST-55104',
        'cost': 160.0,
        'currency': AppConstants.currencyUsd,
        'status': AppConstants.shipmentDispatched,
        'daysAgo': 3,
        'expectedDays': 5,
        'deliveredDays': null,
        'notes': 'طرود بريدية معتمدة عبر مكتب التحرير للبريد السريع',
      },
      {
        'num': 'SHP-YMN-12',
        'title': 'حمولة فرزة مذبح - الحديدة 19 - بضاعة فورية',
        'carrier': 'فرزة النقل السريع بين المحافظات',
        'tracking': 'FRZ-HDD-12490',
        'cost': 65000.0,
        'currency': AppConstants.currencyYer,
        'status': AppConstants.shipmentDistribution,
        'daysAgo': 2,
        'expectedDays': 1,
        'deliveredDays': null,
        'notes': 'دينا نقل سريع خط مناخة - الحوك وصلت نقطة الصباحة',
      },
      {
        'num': 'SHP-YMN-13',
        'title': 'إرسالية الأناضول كارغو تركيا 06 - مفارش وأواني',
        'carrier': 'شركة النور لخدمات الشحن الدولي',
        'tracking': 'NOR-IST-88301',
        'cost': 720.0,
        'currency': AppConstants.currencyUsd,
        'status': AppConstants.shipmentDelivered,
        'daysAgo': 42,
        'expectedDays': 35,
        'deliveredDays': 34,
        'notes': 'مكتملة ومسلّمة للتجار في أسواق إب وتعز وصنعاء',
      },
      {
        'num': 'SHP-YMN-14',
        'title': 'حمولة فرزة الشيخ عثمان - تعز 10 - بضائع محلية',
        'carrier': 'مكتب البركة لنقل البضائع والمهمات',
        'tracking': 'BRK-TAZ-77312',
        'cost': 75000.0,
        'currency': AppConstants.currencyYer,
        'status': AppConstants.shipmentDispatched,
        'daysAgo': 4,
        'expectedDays': 2,
        'deliveredDays': null,
        'notes': 'نقل مباشر عبر خط طور الباحة - جمرك الراهدة إلى تعز',
      },
      {
        'num': 'SHP-YMN-15',
        'title': 'إرسالية ظفار صلالة البرية 12 - بخور ومخلطات',
        'carrier': 'قافلة المهرة للنقل السريع والترانزيت',
        'tracking': 'MHR-SLL-44211',
        'cost': 310.0,
        'currency': AppConstants.currencySar,
        'status': AppConstants.shipmentCheckpoint,
        'daysAgo': 6,
        'expectedDays': 3,
        'deliveredDays': null,
        'notes': 'طرود مسقى عود أصلي وصلت جمرك صرفيت في المهرة',
      },
    ];

    // =========================================================================
    // 3. كتالوج السلع والبضائع من صميم السوق والتجارة اليمنية
    // =========================================================================
    final itemCatalog = <Map<String, dynamic>>[
      {
        'name': 'عسل سدر دوعني ملكي فاخر دبة 1 كجم أصلي دوعن',
        'desc': 'طبيعي 100% مفحوص مخبرياً من مناحل وادي دوعن بحضرموت',
        'costSar': 240.0,
        'sellSar': 350.0,
        'costUsd': 64.0,
        'sellUsd': 93.0,
        'costYer': 128000.0,
        'sellYer': 187000.0,
      },
      {
        'name': 'عسل جرداني شبواني فاخر قطفة أولى نصف كيلو',
        'desc': 'عسل نقي ذو لزوجة ورائحة عطرية مميزة من مراعي جردان شبوة',
        'costSar': 150.0,
        'sellSar': 220.0,
        'costUsd': 40.0,
        'sellUsd': 58.0,
        'costYer': 80000.0,
        'sellYer': 118000.0,
      },
      {
        'name': 'بخور عدني عرائسي فاخر طبخة ملكية أصلية',
        'desc': 'مطبوخ بدهن العود والمسك والعنبر والورد برائحة تدوم أياماً',
        'costSar': 90.0,
        'sellSar': 140.0,
        'costUsd': 24.0,
        'sellUsd': 37.0,
        'costYer': 48000.0,
        'sellYer': 75000.0,
      },
      {
        'name': 'جنبية صيفاني نقش مميز مع حزام مطرز أصلي (عسيب)',
        'desc': 'رأس صيفاني لمعة كهرمان مع غمد مذهب وحزام خيوط سيم فضي صنعاني',
        'costSar': 650.0,
        'sellSar': 920.0,
        'costUsd': 173.0,
        'sellUsd': 245.0,
        'costYer': 348000.0,
        'sellYer': 492000.0,
      },
      {
        'name': 'بن يافعي أصلي درجة أولى حمصة وسط دبل خولاني (1 كجم)',
        'desc': 'حبوب بن جبلية منتقاة بعناية لنكهة قهوة يمنية أصيلة فاخرة',
        'costSar': 85.0,
        'sellSar': 130.0,
        'costUsd': 23.0,
        'sellUsd': 35.0,
        'costYer': 45000.0,
        'sellYer': 69000.0,
      },
      {
        'name': 'بن خولاني حيمي فاخر قشر صافي للقهوة الصباحية (2 كجم)',
        'desc': 'قشر بن خولاني بلدي خفيف ونقي مع زنجبيل وهيل ونخوة',
        'costSar': 55.0,
        'sellSar': 85.0,
        'costUsd': 15.0,
        'sellUsd': 23.0,
        'costYer': 29000.0,
        'sellYer': 45000.0,
      },
      {
        'name': 'لوح طاقة شمسية مونو كريستال 450 واط كندي أصلي',
        'desc': 'كفاءة تحويل عالية حتى في الأيام الغائمة وضمان أداء 10 سنوات',
        'costSar': 280.0,
        'sellSar': 390.0,
        'costUsd': 75.0,
        'sellUsd': 104.0,
        'costYer': 150000.0,
        'sellYer': 208000.0,
      },
      {
        'name': 'إنفرتر هجين ذكي 3.5 كيلو واط مع شاحن MPPT للطاقة',
        'desc': 'موجة جيبية نقية متوافق مع بطاريات الليثيوم والجل للمنازل',
        'costSar': 850.0,
        'sellSar': 1150.0,
        'costUsd': 227.0,
        'sellUsd': 307.0,
        'costYer': 455000.0,
        'sellYer': 615000.0,
      },
      {
        'name': 'بطارية ليثيوم 48V فوسفات حديد 100Ah لتخزين الطاقة',
        'desc': 'شحن سريع وأكثر من 4000 دورة تفريغ مناسبة للكهرباء المنزلية',
        'costSar': 1850.0,
        'sellSar': 2350.0,
        'costUsd': 493.0,
        'sellUsd': 626.0,
        'costYer': 990000.0,
        'sellYer': 1257000.0,
      },
      {
        'name': 'راوتر يمن فورجي ZTE يدعم شبكة 4G VoLTE السريعة',
        'desc': 'مدى تغطية واي فاي واسع مع هوائيات تقوية لشبكة يمن موبايل',
        'costSar': 140.0,
        'sellSar': 210.0,
        'costUsd': 37.0,
        'sellUsd': 56.0,
        'costYer': 75000.0,
        'sellYer': 112000.0,
      },
      {
        'name': 'شال كشميري ترمة دبل نقش يدوي صوف طبيعي 100%',
        'desc': 'حياكة كشميرية ناعمة نقشة ملكية للمناسبات والأعراس والمجالس',
        'costSar': 380.0,
        'sellSar': 540.0,
        'costUsd': 101.0,
        'sellUsd': 144.0,
        'costYer': 203000.0,
        'sellYer': 289000.0,
      },
      {
        'name': 'معوز بيضاني شبواني حياكة يدوية خيط قطن ممتاز',
        'desc': 'حياكة تقليدية خيوط زاهية ونسيج محبوك يدوم لسنوات',
        'costSar': 120.0,
        'sellSar': 180.0,
        'costUsd': 32.0,
        'sellUsd': 48.0,
        'costYer': 64000.0,
        'sellYer': 96000.0,
      },
      {
        'name': 'مفرش سرير تركي قطن ملكي 6 قطع مطرز',
        'desc': 'خامة قطنية باردة وألوان ثابتة وملمس ناعم لغرف النوم',
        'costSar': 170.0,
        'sellSar': 250.0,
        'costUsd': 45.0,
        'sellUsd': 67.0,
        'costYer': 91000.0,
        'sellYer': 134000.0,
      },
      {
        'name': 'حرضة صخر يمنية أصلية مقاس كبير للمداقي والسلتة',
        'desc': 'منحوتة يدوياً من جبال صعدة تحتفظ بحرارة الطعام وتكسبه طعماً مميزاً',
        'costSar': 65.0,
        'sellSar': 105.0,
        'costUsd': 17.0,
        'sellUsd': 28.0,
        'costYer': 35000.0,
        'sellYer': 56000.0,
      },
      {
        'name': 'طقم قدور ضغط سب فرنسي أصلي 10 لتر للمندي واللحم',
        'desc': 'ستانلس ستيل ثقيل صمامات أمان مزدوجة للمطبخ المنزلي والمطاعم',
        'costSar': 320.0,
        'sellSar': 460.0,
        'costUsd': 85.0,
        'sellUsd': 123.0,
        'costYer': 171000.0,
        'sellYer': 246000.0,
      },
      {
        'name': 'دلة رسلان نحاسية صفراء تراثية للقهوة والشاي العدني',
        'desc': 'نحاس أصلي مدموغ نقش يدوي قديم صبّة ممتازة للمجالس',
        'costSar': 110.0,
        'sellSar': 165.0,
        'costUsd': 29.0,
        'sellUsd': 44.0,
        'costYer': 59000.0,
        'sellYer': 88000.0,
      },
      {
        'name': 'لوز خولاني جبلي محمص بلدي مقشر كيس 2 كجم',
        'desc': 'حبات لوز بلدي مقرمشة غنية بالزيوت الطبيعية من مزارع خولان',
        'costSar': 130.0,
        'sellSar': 190.0,
        'costUsd': 35.0,
        'sellUsd': 51.0,
        'costYer': 70000.0,
        'sellYer': 102000.0,
      },
      {
        'name': 'زبيب رازقي صعدي ذهبي درجة أولى خالي من الشوائب 2 كجم',
        'desc': 'طعم سكري طبيعي وحبات ممتلئة مجففة بعناية فائقة',
        'costSar': 75.0,
        'sellSar': 115.0,
        'costUsd': 20.0,
        'sellUsd': 31.0,
        'costYer': 40000.0,
        'sellYer': 61000.0,
      },
      {
        'name': 'عطر مخلط دهن العود الكمبودي والورد الطائفي (تولة)',
        'desc': 'رائحة شيوخية عميقة تجمع بين دفء العود المعتق وانتعاش الورد',
        'costSar': 160.0,
        'sellSar': 240.0,
        'costUsd': 43.0,
        'sellUsd': 64.0,
        'costYer': 85000.0,
        'sellYer': 128000.0,
      },
      {
        'name': 'ثوب يمني مطرز قماش كوري شك أصيل مع الجبّة',
        'desc': 'تفصيل وخياطة يمنية متقنة للأعياد والمناسبات الاجتماعية',
        'costSar': 190.0,
        'sellSar': 280.0,
        'costUsd': 51.0,
        'sellUsd': 75.0,
        'costYer': 101000.0,
        'sellYer': 150000.0,
      },
    ];

    // =========================================================================
    // 4. تنفيذ التوليد الجماعي داخل معاملة (Transaction) سريعة
    // =========================================================================
    // خريطة ربط فهارس الكتالوج بالمنتجات التجريبية في جدول products
    // لتوليد تقارير حقيقية تقارن بين (البيع والشراء) و(التصنيع والإنتاج)
    final Map<int, String> catalogIndexToProductId = {
      0: 'demo_prod_1',
      1: 'demo_prod_2',
      2: 'demo_prod_3',
      3: 'demo_prod_4',
      4: 'demo_prod_5',
      5: 'demo_prod_6',
      10: 'demo_prod_7',
      11: 'demo_prod_8',
      18: 'demo_prod_9',
      19: 'demo_prod_10',
    };

    String formatDateOnly(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    await db.transaction((txn) async {
      // -----------------------------------------------------------------------
      // أ. إدخال الموردين (6 موردين واقعيين بمختلف التصنيفات)
      // -----------------------------------------------------------------------
      final supplierDefinitions = <Map<String, dynamic>>[
        {
          'id': 'demo_sup_1',
          'name': 'مؤسسة الروضة للمواد الخام والبهارات',
          'phone': '+967 771100201',
          'whatsapp': '+967 771100201',
          'category': 'sup_cat_materials',
          'address': 'باب اليمن - سوق البهارات والمواد الخام، صنعاء',
          'notes': 'توريد بن يافعي أخضر، هيل، دقيق وتمر بالجملة',
        },
        {
          'id': 'demo_sup_2',
          'name': 'مطبعة ومصنع الخليج للعلب والتغليف',
          'phone': '+967 772200302',
          'whatsapp': '+967 772200302',
          'category': 'sup_cat_packaging',
          'address': 'شارع الستين الجنوبي - صنعاء',
          'notes': 'علب هدايا فاخرة، عبوات زجاجية وأكياس مطبوعة بالهوية',
        },
        {
          'id': 'demo_sup_3',
          'name': 'وكالة باحارثة لتجارة العسل والبن بالجملة',
          'phone': '+967 711300403',
          'whatsapp': '+967 711300403',
          'category': 'sup_cat_wholesale',
          'address': 'الشرج - المكلا، حضرموت',
          'notes': 'توريد عسل سدر دوعني وجرداني شبواني مفحوص بأسعار الجملة',
        },
        {
          'id': 'demo_sup_4',
          'name': 'شركة الأصالة للزيوت العطرية ودهن العود',
          'phone': '+967 733400504',
          'whatsapp': '+967 733400504',
          'category': 'sup_cat_materials',
          'address': 'كريتر - شارع أروى، عدن',
          'notes': 'خشب عود كمبودي خام، عنبر ومسك وورد طائفي للتصنيع',
        },
        {
          'id': 'demo_sup_5',
          'name': 'مركز النخبة لتجارة الأقمشة والشيلان',
          'phone': '+967 774500605',
          'whatsapp': '+967 774500605',
          'category': 'sup_cat_wholesale',
          'address': 'سوق الزمر - صنعاء القديمة',
          'notes': 'شيلان كشميرية، معاوز بيضانية وأقمشة تراثية جاهزة للبيع',
        },
        {
          'id': 'demo_sup_6',
          'name': 'مندوب السريع للتوصيل المحلي',
          'phone': '+967 775600706',
          'whatsapp': '+967 775600706',
          'category': 'sup_cat_services',
          'address': 'حي حدة - صنعاء',
          'notes': 'توصيل طلبات الأسر المنتجة داخل المدينة وتحصيل الدفع عند الاستلام',
        },
      ];

      for (int i = 0; i < supplierDefinitions.length; i++) {
        final sup = supplierDefinitions[i];
        await txn.insert('suppliers', {
          'id': sup['id'],
          'name': sup['name'],
          'phone': sup['phone'],
          'whatsapp': sup['whatsapp'],
          'category': sup['category'],
          'address': sup['address'],
          'notes': sup['notes'],
          'createdAt': now.subtract(Duration(days: 45 - i * 3)).toIso8601String(),
        });
      }

      // -----------------------------------------------------------------------
      // ب. إدخال المواد الخام المرتبطة بالموردين مع كميات المخزون وحد التنبيه
      // -----------------------------------------------------------------------
      final rawMaterialDefinitions = <Map<String, dynamic>>[
        {
          'id': 'demo_mat_1',
          'name': 'خشب عود كمبودي خام فاخر',
          'unit': 'كجم',
          'unitCost': 45000.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_4',
          'stockQuantity': 2.5,
          'lowStockThreshold': 3.0, // مخزون منخفض لاختبار التنبيهات
          'notes': 'لتحضير طبخات البخور العدني العرائسي',
        },
        {
          'id': 'demo_mat_2',
          'name': 'دهن عود وعنبر ومسك مخلط',
          'unit': 'تولة',
          'unitCost': 6500.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_4',
          'stockQuantity': 18.0,
          'lowStockThreshold': 5.0,
          'notes': 'تركيز عالٍ للعطور والبخور',
        },
        {
          'id': 'demo_mat_3',
          'name': 'حبوب بن يافعي أخضر درجة أولى',
          'unit': 'كجم',
          'unitCost': 18000.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_1',
          'stockQuantity': 14.0,
          'lowStockThreshold': 4.0,
          'notes': 'للتحميص والتعبئة الطازجة',
        },
        {
          'id': 'demo_mat_4',
          'name': 'دقيق فاخر وسمن بلدي وتمر خلاص',
          'unit': 'كجم',
          'unitCost': 3200.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_1',
          'stockQuantity': 22.0,
          'lowStockThreshold': 6.0,
          'notes': 'مكونات أساسية لمعمول الضيافة',
        },
        {
          'id': 'demo_mat_5',
          'name': 'هيل وزنجبيل وتوابل قهوة فاخرة',
          'unit': 'كجم',
          'unitCost': 12000.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_1',
          'stockQuantity': 1.5,
          'lowStockThreshold': 2.0, // مخزون منخفض
          'notes': 'خلطة البهارات للبن والقشر الخولاني',
        },
        {
          'id': 'demo_mat_6',
          'name': 'علب تغليف هدايا فاخرة مع شريط',
          'unit': 'علبة',
          'unitCost': 1200.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_2',
          'stockQuantity': 60.0,
          'lowStockThreshold': 15.0,
          'notes': 'علب كرتون مقوى بشعار المتجر',
        },
        {
          'id': 'demo_mat_7',
          'name': 'أكياس قماشية مطبوعة بالعلامة',
          'unit': 'كيس',
          'unitCost': 600.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_2',
          'stockQuantity': 90.0,
          'lowStockThreshold': 20.0,
          'notes': 'أكياس تغليف للبن والمكسرات',
        },
        {
          'id': 'demo_mat_8',
          'name': 'عبوات زجاجية محكمة الإغلاق للبخور والعطور',
          'unit': 'عبوة',
          'unitCost': 900.0,
          'currency': AppConstants.currencyYer,
          'supplierId': 'demo_sup_2',
          'stockQuantity': 45.0,
          'lowStockThreshold': 10.0,
          'notes': 'تحفظ الرائحة وتمنع التسرب',
        },
      ];

      for (int i = 0; i < rawMaterialDefinitions.length; i++) {
        final mat = rawMaterialDefinitions[i];
        await txn.insert('raw_materials', {
          'id': mat['id'],
          'name': mat['name'],
          'unit': mat['unit'],
          'unitCost': mat['unitCost'],
          'currency': mat['currency'],
          'supplierId': mat['supplierId'],
          'notes': mat['notes'],
          'stockQuantity': mat['stockQuantity'],
          'lowStockThreshold': mat['lowStockThreshold'],
          'createdAt': now.subtract(Duration(days: 40 - i * 2)).toIso8601String(),
        });
      }

      // -----------------------------------------------------------------------
      // ج. إدخال قوالب التصنيع وبنودها
      // -----------------------------------------------------------------------
      final templates = <Map<String, dynamic>>[
        {
          'id': 'demo_tpl_1',
          'name': 'قالب طبخة البخور العدني والعطور الملكية',
          'description': 'وصفة إنتاج دفعة من 10 عبوات بخور وعطر فاخر شاملة التغليف وأجر التحضير',
          'yieldCount': 10,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpl_2',
          'name': 'قالب تحميص وتعبئة البن اليافعي والخولاني',
          'description': 'تحميص وطحن وتعبئة 8 عبوات بن يمني مختص مع التوابل والتغليف',
          'yieldCount': 8,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpl_3',
          'name': 'قالب تجهيز حلويات ومعمول الضيافة',
          'description': 'إنتاج 12 علبة ضيافة فاخرة شاملة المواد الخام والعلب والغاز',
          'yieldCount': 12,
          'currency': AppConstants.currencyYer,
        },
      ];

      for (int i = 0; i < templates.length; i++) {
        final t = templates[i];
        await txn.insert('manufacturing_templates', {
          'id': t['id'],
          'name': t['name'],
          'description': t['description'],
          'yieldCount': t['yieldCount'],
          'currency': t['currency'],
          'createdAt': now.subtract(Duration(days: 35 - i * 3)).toIso8601String(),
        });
      }

      final templateItems = <Map<String, dynamic>>[
        // قالب 1: بخور وعطور
        {
          'id': 'demo_tpli_1',
          'templateId': 'demo_tpl_1',
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_1',
          'name': 'خشب عود كمبودي خام فاخر',
          'quantity': 4.0,
          'unit': 'كجم',
          'unitCost': 45000.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_2',
          'templateId': 'demo_tpl_1',
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_2',
          'name': 'دهن عود وعنبر ومسك مخلط',
          'quantity': 20.0,
          'unit': 'تولة',
          'unitCost': 6500.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_3',
          'templateId': 'demo_tpl_1',
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_8',
          'name': 'عبوات زجاجية محكمة الإغلاق',
          'quantity': 10.0,
          'unit': 'عبوة',
          'unitCost': 900.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_4',
          'templateId': 'demo_tpl_1',
          'itemType': AppConstants.costItemLabor,
          'materialId': null,
          'name': 'أجر الطبخ والتعتيق والتعبئة',
          'quantity': 1.0,
          'unit': 'دفعة',
          'unitCost': 30000.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_5',
          'templateId': 'demo_tpl_1',
          'itemType': AppConstants.costItemUtilities,
          'materialId': null,
          'name': 'غاز وكهرباء الطبخة',
          'quantity': 1.0,
          'unit': 'دفعة',
          'unitCost': 11000.0,
          'currency': AppConstants.currencyYer,
        },
        // قالب 2: بن يمني
        {
          'id': 'demo_tpli_6',
          'templateId': 'demo_tpl_2',
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_3',
          'name': 'حبوب بن يافعي أخضر درجة أولى',
          'quantity': 10.0,
          'unit': 'كجم',
          'unitCost': 18000.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_7',
          'templateId': 'demo_tpl_2',
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_5',
          'name': 'هيل وزنجبيل وتوابل قهوة فاخرة',
          'quantity': 2.0,
          'unit': 'كجم',
          'unitCost': 12000.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_8',
          'templateId': 'demo_tpl_2',
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_7',
          'name': 'أكياس قماشية مطبوعة بالعلامة',
          'quantity': 8.0,
          'unit': 'كيس',
          'unitCost': 600.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_9',
          'templateId': 'demo_tpl_2',
          'itemType': AppConstants.costItemLabor,
          'materialId': null,
          'name': 'تحميص وطحن وتغليف',
          'quantity': 1.0,
          'unit': 'دفعة',
          'unitCost': 15200.0,
          'currency': AppConstants.currencyYer,
        },
        // قالب 3: معمول ضيافة
        {
          'id': 'demo_tpli_10',
          'templateId': 'demo_tpl_3',
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_4',
          'name': 'دقيق فاخر وسمن بلدي وتمر خلاص',
          'quantity': 8.0,
          'unit': 'كجم',
          'unitCost': 3200.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_11',
          'templateId': 'demo_tpl_3',
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_6',
          'name': 'علب تغليف هدايا فاخرة مع شريط',
          'quantity': 12.0,
          'unit': 'علبة',
          'unitCost': 1200.0,
          'currency': AppConstants.currencyYer,
        },
        {
          'id': 'demo_tpli_12',
          'templateId': 'demo_tpl_3',
          'itemType': AppConstants.costItemUtilities,
          'materialId': null,
          'name': 'فرن وغاز وتبريد',
          'quantity': 1.0,
          'unit': 'دفعة',
          'unitCost': 8000.0,
          'currency': AppConstants.currencyYer,
        },
      ];

      for (final ti in templateItems) {
        await txn.insert('manufacturing_template_items', ti);
      }

      // -----------------------------------------------------------------------
      // د. إدخال منتجات الكتالوج (5 بيع وشراء + 5 تصنيع وإنتاج) + مكونات التصنيع
      // -----------------------------------------------------------------------
      final productDefinitions = <Map<String, dynamic>>[
        // منتجات بيع وشراء (Resale)
        {
          'id': 'demo_prod_1',
          'name': itemCatalog[0]['name'],
          'category': 'cat_food_sweets',
          'unit': 'دبة 1 كجم',
          'costPrice': 128000.0,
          'sellPrice': 187000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 14,
          'trackStock': 1,
          'lowStockThreshold': 4,
          'supplierId': 'demo_sup_3',
          'productType': AppConstants.productTypeResale,
          'batchYield': 1,
          'templateId': null,
          'notes': itemCatalog[0]['desc'],
        },
        {
          'id': 'demo_prod_2',
          'name': itemCatalog[1]['name'],
          'category': 'cat_food_sweets',
          'unit': 'نصف كجم',
          'costPrice': 80000.0,
          'sellPrice': 118000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 10,
          'trackStock': 1,
          'lowStockThreshold': 3,
          'supplierId': 'demo_sup_3',
          'productType': AppConstants.productTypeResale,
          'batchYield': 1,
          'templateId': null,
          'notes': itemCatalog[1]['desc'],
        },
        {
          'id': 'demo_prod_4',
          'name': itemCatalog[3]['name'],
          'category': 'cat_gifts_crafts',
          'unit': 'طقم',
          'costPrice': 348000.0,
          'sellPrice': 492000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 4,
          'trackStock': 1,
          'lowStockThreshold': 2,
          'supplierId': 'demo_sup_5',
          'productType': AppConstants.productTypeResale,
          'batchYield': 1,
          'templateId': null,
          'notes': itemCatalog[3]['desc'],
        },
        {
          'id': 'demo_prod_7',
          'name': itemCatalog[10]['name'],
          'category': 'cat_fashion_sewing',
          'unit': 'شال',
          'costPrice': 203000.0,
          'sellPrice': 289000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 2,
          'trackStock': 1,
          'lowStockThreshold': 3, // مخزون منخفض
          'supplierId': 'demo_sup_5',
          'productType': AppConstants.productTypeResale,
          'batchYield': 1,
          'templateId': null,
          'notes': itemCatalog[10]['desc'],
        },
        {
          'id': 'demo_prod_8',
          'name': itemCatalog[11]['name'],
          'category': 'cat_fashion_sewing',
          'unit': 'معوز',
          'costPrice': 64000.0,
          'sellPrice': 96000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 16,
          'trackStock': 1,
          'lowStockThreshold': 4,
          'supplierId': 'demo_sup_5',
          'productType': AppConstants.productTypeResale,
          'batchYield': 1,
          'templateId': null,
          'notes': itemCatalog[11]['desc'],
        },
        // منتجات تصنيع وإنتاج (Manufactured)
        {
          'id': 'demo_prod_3',
          'name': itemCatalog[2]['name'],
          'category': 'cat_perfume_bakhoor',
          'unit': 'عبوة',
          'costPrice': 48000.0,
          'sellPrice': 75000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 12,
          'trackStock': 1,
          'lowStockThreshold': 4,
          'supplierId': 'demo_sup_4',
          'productType': AppConstants.productTypeManufactured,
          'batchYield': 10,
          'templateId': 'demo_tpl_1',
          'reorderCycleDays': 7,
          'notes': itemCatalog[2]['desc'],
        },
        {
          'id': 'demo_prod_5',
          'name': itemCatalog[4]['name'],
          'category': 'cat_food_sweets',
          'unit': 'كجم',
          'costPrice': 45000.0,
          'sellPrice': 69000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 15,
          'trackStock': 1,
          'lowStockThreshold': 4,
          'supplierId': 'demo_sup_1',
          'productType': AppConstants.productTypeManufactured,
          'batchYield': 8,
          'templateId': 'demo_tpl_2',
          'notes': itemCatalog[4]['desc'],
        },
        {
          'id': 'demo_prod_6',
          'name': itemCatalog[5]['name'],
          'category': 'cat_food_sweets',
          'unit': 'كيس 2 كجم',
          'costPrice': 29000.0,
          'sellPrice': 45000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 9,
          'trackStock': 1,
          'lowStockThreshold': 3,
          'supplierId': 'demo_sup_1',
          'productType': AppConstants.productTypeManufactured,
          'batchYield': 8,
          'templateId': 'demo_tpl_2',
          'notes': itemCatalog[5]['desc'],
        },
        {
          'id': 'demo_prod_9',
          'name': itemCatalog[18]['name'],
          'category': 'cat_perfume_bakhoor',
          'unit': 'تولة',
          'costPrice': 85000.0,
          'sellPrice': 128000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 2,
          'trackStock': 1,
          'lowStockThreshold': 3, // مخزون منخفض
          'supplierId': 'demo_sup_4',
          'productType': AppConstants.productTypeManufactured,
          'batchYield': 10,
          'templateId': 'demo_tpl_1',
          'notes': itemCatalog[18]['desc'],
        },
        {
          'id': 'demo_prod_10',
          'name': itemCatalog[19]['name'],
          'category': 'cat_fashion_sewing',
          'unit': 'طقم',
          'costPrice': 101000.0,
          'sellPrice': 150000.0,
          'currency': AppConstants.currencyYer,
          'stockQuantity': 6,
          'trackStock': 1,
          'lowStockThreshold': 2,
          'supplierId': 'demo_sup_2',
          'productType': AppConstants.productTypeManufactured,
          'batchYield': 12,
          'templateId': 'demo_tpl_3',
          'notes': itemCatalog[19]['desc'],
        },
      ];

      for (int i = 0; i < productDefinitions.length; i++) {
        final p = productDefinitions[i];
        await txn.insert('products', {
          ...p,
          'isActive': 1,
          'createdAt': now.subtract(Duration(days: 30 - i * 2)).toIso8601String(),
        });
      }

      // مكونات التصنيع (product_ingredients) للمنتجات التصنيعية
      final demoIngredients = <Map<String, dynamic>>[
        // demo_prod_3: بخور عدني
        {
          'id': 'demo_ing_1',
          'productId': 'demo_prod_3',
          'name': 'خشب عود كمبودي خام فاخر',
          'cost': 180000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 10,
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_1',
          'quantity': 4.0,
          'unit': 'كجم',
          'unitCost': 45000.0,
        },
        {
          'id': 'demo_ing_2',
          'productId': 'demo_prod_3',
          'name': 'دهن عود وعنبر ومسك مخلط',
          'cost': 130000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 10,
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_2',
          'quantity': 20.0,
          'unit': 'تولة',
          'unitCost': 6500.0,
        },
        {
          'id': 'demo_ing_3',
          'productId': 'demo_prod_3',
          'name': 'عبوات زجاجية محكمة الإغلاق',
          'cost': 9000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 10,
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_8',
          'quantity': 10.0,
          'unit': 'عبوة',
          'unitCost': 900.0,
        },
        // demo_prod_5: بن يافعي
        {
          'id': 'demo_ing_4',
          'productId': 'demo_prod_5',
          'name': 'حبوب بن يافعي أخضر درجة أولى',
          'cost': 180000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 8,
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_3',
          'quantity': 10.0,
          'unit': 'كجم',
          'unitCost': 18000.0,
        },
        {
          'id': 'demo_ing_5',
          'productId': 'demo_prod_5',
          'name': 'هيل وزنجبيل وتوابل قهوة فاخرة',
          'cost': 24000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 8,
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_5',
          'quantity': 2.0,
          'unit': 'كجم',
          'unitCost': 12000.0,
        },
        {
          'id': 'demo_ing_6',
          'productId': 'demo_prod_5',
          'name': 'أكياس قماشية مطبوعة بالعلامة',
          'cost': 4800.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 8,
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_7',
          'quantity': 8.0,
          'unit': 'كيس',
          'unitCost': 600.0,
        },
        // demo_prod_6: بن خولاني
        {
          'id': 'demo_ing_7',
          'productId': 'demo_prod_6',
          'name': 'حبوب بن يافعي أخضر درجة أولى',
          'cost': 144000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 8,
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_3',
          'quantity': 8.0,
          'unit': 'كجم',
          'unitCost': 18000.0,
        },
        {
          'id': 'demo_ing_8',
          'productId': 'demo_prod_6',
          'name': 'أكياس قماشية مطبوعة بالعلامة',
          'cost': 4800.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 8,
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_7',
          'quantity': 8.0,
          'unit': 'كيس',
          'unitCost': 600.0,
        },
        // demo_prod_9: عطر مخلط
        {
          'id': 'demo_ing_9',
          'productId': 'demo_prod_9',
          'name': 'دهن عود وعنبر ومسك مخلط',
          'cost': 65000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 10,
          'itemType': AppConstants.costItemMaterial,
          'materialId': 'demo_mat_2',
          'quantity': 10.0,
          'unit': 'تولة',
          'unitCost': 6500.0,
        },
        {
          'id': 'demo_ing_10',
          'productId': 'demo_prod_9',
          'name': 'عبوات زجاجية محكمة الإغلاق',
          'cost': 9000.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 10,
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_8',
          'quantity': 10.0,
          'unit': 'عبوة',
          'unitCost': 900.0,
        },
        // demo_prod_10: ثوب مطرز / ضيافة
        {
          'id': 'demo_ing_11',
          'productId': 'demo_prod_10',
          'name': 'علب تغليف هدايا فاخرة مع شريط',
          'cost': 14400.0,
          'currency': AppConstants.currencyYer,
          'yieldCount': 12,
          'itemType': AppConstants.costItemPackaging,
          'materialId': 'demo_mat_6',
          'quantity': 12.0,
          'unit': 'علبة',
          'unitCost': 1200.0,
        },
      ];

      for (final ing in demoIngredients) {
        await txn.insert('product_ingredients', ing);
      }

      // دفعات إنتاج تجريبية (production_batches)
      await txn.insert('production_batches', {
        'id': 'demo_batch_1',
        'productId': 'demo_prod_3',
        'productName': itemCatalog[2]['name'],
        'yieldCount': 10,
        'totalCost': 360000.0,
        'currency': AppConstants.currencyYer,
        'notes': 'دفعة بخور عرائسي للموسم',
        'producedAt': now.subtract(const Duration(days: 5)).toIso8601String(),
      });
      await txn.insert('production_batches', {
        'id': 'demo_batch_2',
        'productId': 'demo_prod_5',
        'productName': itemCatalog[4]['name'],
        'yieldCount': 8,
        'totalCost': 224000.0,
        'currency': AppConstants.currencyYer,
        'notes': 'دفعة تحميص طازجة',
        'producedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      });

      // -----------------------------------------------------------------------
      // د2. بيانات المرحلة السادسة: باقات المنتجات، المتغيرات، التعتيق والهالك
      // -----------------------------------------------------------------------
      // 1) باقة مجمعة تجريبية (demo_prod_bundle_1) + مكونين
      await txn.insert('products', {
        'id': 'demo_prod_bundle_1',
        'name': 'باقة ضيافة العيد الفاخرة (بخور عدني + عطر مخلط)',
        'category': 'cat_perfume_bakhoor',
        'unit': 'باقة',
        'costPrice': 133000.0,
        'sellPrice': 185000.0,
        'currency': AppConstants.currencyYer,
        'stockQuantity': 0,
        'trackStock': 0,
        'lowStockThreshold': 0,
        'supplierId': 'demo_sup_4',
        'productType': AppConstants.productTypeResale,
        'batchYield': 1,
        'templateId': null,
        'isBundle': 1,
        'notes': 'باقة موسمية جاهزة للضيافة والهدايا',
        'isActive': 1,
        'createdAt': now.subtract(const Duration(days: 4)).toIso8601String(),
      });
      await txn.insert('product_bundle_items', {
        'id': 'demo_bundle_item_1',
        'bundleProductId': 'demo_prod_bundle_1',
        'componentProductId': 'demo_prod_3',
        'componentName': itemCatalog[2]['name'],
        'quantity': 1,
      });
      await txn.insert('product_bundle_items', {
        'id': 'demo_bundle_item_2',
        'bundleProductId': 'demo_prod_bundle_1',
        'componentProductId': 'demo_prod_9',
        'componentName': itemCatalog[18]['name'],
        'quantity': 1,
      });

      // 2) متغيرات/أحجام تجريبية على منتج بخور عدني (demo_prod_3)
      await txn.insert('product_variants', {
        'id': 'demo_var_1',
        'productId': 'demo_prod_3',
        'variantName': 'عبوة 50 جم (حجم قياسي)',
        'sku': 'BKH-50G',
        'costPrice': 48000.0,
        'sellPrice': 75000.0,
        'stockQuantity': 8,
        'isActive': 1,
      });
      await txn.insert('product_variants', {
        'id': 'demo_var_2',
        'productId': 'demo_prod_3',
        'variantName': 'عبوة 100 جم (حجم ملكي)',
        'sku': 'BKH-100G',
        'costPrice': 88000.0,
        'sellPrice': 135000.0,
        'stockQuantity': 4,
        'isActive': 1,
      });

      // 3) دفعة قيد التعتيق (Curing Batch) ستجهز بعد 5 أيام وتنتهي بعد 35 يوماً
      await txn.insert('production_batches', {
        'id': 'demo_batch_curing_1',
        'productId': 'demo_prod_9',
        'productName': itemCatalog[18]['name'],
        'yieldCount': 10,
        'totalCost': 185000.0,
        'currency': AppConstants.currencyYer,
        'notes': 'طبخة عطر مخلط قيد التعتيق 5 أيام',
        'producedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        'batchStatus': AppConstants.batchStatusCuring,
        'readyAt': now.add(const Duration(days: 5)).toIso8601String(),
        'expiresAt': now.add(const Duration(days: 35)).toIso8601String(),
      });

      // 4) سجل هالك وتالف تجريبي (waste_logs)
      await txn.insert('waste_logs', {
        'id': 'demo_waste_1',
        'itemType': 'product',
        'itemId': 'demo_prod_5',
        'itemName': itemCatalog[4]['name'],
        'quantity': 1.0,
        'unit': 'كجم',
        'estimatedLossYer': 45000.0,
        'reason': AppConstants.wasteReasonSpoiled,
        'notes': 'تلف رطوبة أثناء التخزين (بيانات تجريبية)',
        'loggedAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      });

      // -----------------------------------------------------------------------
      // هـ. إدخال العملاء (35 عميلاً)
      // -----------------------------------------------------------------------
      for (int i = 0; i < customerDefinitions.length; i++) {
        final cust = customerDefinitions[i];
        final custId = 'demo_cust_${i + 1}';
        final createdAt = now.subtract(Duration(days: 50 - (i % 35)));
        await txn.insert('customers', {
          'id': custId,
          'name': cust['name']!,
          'phone': cust['phone'],
          'whatsapp': cust['whatsapp'],
          'notes': cust['notes'],
          'returnCount': i == 2 ? 2 : 0,
          'createdAt': createdAt.toIso8601String(),
        });
      }

      // -----------------------------------------------------------------------
      // هـ2. إدخال مندوبي التوصيل التجريبيين (2 مندوبين) + دفتر حساب مورد (آجل + سداد)
      // -----------------------------------------------------------------------
      await txn.insert('couriers', {
        'id': 'demo_courier_1',
        'name': 'أحمد للتوصيل السريع',
        'phone': '+967 771900101',
        'whatsapp': '+967 771900101',
        'defaultFee': 1500.0,
        'currency': AppConstants.currencyYer,
        'notes': 'توصيل أحياء صنعاء: حدة، الأصبحي، الستين',
        'createdAt': now.subtract(const Duration(days: 20)).toIso8601String(),
      });
      await txn.insert('couriers', {
        'id': 'demo_courier_2',
        'name': 'سالم إكسبريس للطرود',
        'phone': '+967 711900202',
        'whatsapp': '+967 711900202',
        'defaultFee': 2000.0,
        'currency': AppConstants.currencyYer,
        'notes': 'توصيل الطلبات بين الأحياء البعيدة وتحصيل الدفع عند الاستلام',
        'createdAt': now.subtract(const Duration(days: 15)).toIso8601String(),
      });

      await txn.insert('supplier_transactions', {
        'id': 'demo_sup_tx_1',
        'supplierId': 'demo_sup_1',
        'type': AppConstants.supplierTxPurchaseCredit,
        'amount': 180000.0,
        'currency': AppConstants.currencyYer,
        'notes': 'توريد دفعة بن يافعي وهيل على الحساب',
        'receiptPhotoPath': null,
        'txDate': now.subtract(const Duration(days: 6)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 6)).toIso8601String(),
      });
      await txn.insert('supplier_transactions', {
        'id': 'demo_sup_tx_2',
        'supplierId': 'demo_sup_1',
        'type': AppConstants.supplierTxPayment,
        'amount': 80000.0,
        'currency': AppConstants.currencyYer,
        'notes': 'دفعة سداد أولى للمورد نقداً',
        'receiptPhotoPath': null,
        'txDate': now.subtract(const Duration(days: 2)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      });

      // -----------------------------------------------------------------------
      // و. إدخال الشحنات المجمعة (15 شحنة)
      // -----------------------------------------------------------------------
      for (int i = 0; i < shipmentDefinitions.length; i++) {
        final ship = shipmentDefinitions[i];
        final shipId = 'demo_ship_${i + 1}';
        final daysAgo = ship['daysAgo'] as int;
        final createdAt = now.subtract(Duration(days: daysAgo));
        final expectedDays = ship['expectedDays'] as int?;
        final deliveredDays = ship['deliveredDays'] as int?;

        final expectedDeliveryDate = expectedDays != null
            ? now.add(Duration(days: expectedDays))
            : null;
        final actualDeliveryDate = deliveredDays != null
            ? now.subtract(Duration(days: deliveredDays))
            : null;

        await txn.insert('shipments', {
          'id': shipId,
          'shipmentNumber': ship['num'],
          'title': ship['title'],
          'carrierName': ship['carrier'],
          'trackingNumber': ship['tracking'],
          'transportCost': ship['cost'],
          'transportCostCurrency': ship['currency'],
          'status': ship['status'],
          'createdAt': createdAt.toIso8601String(),
          'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
          'actualDeliveryDate': actualDeliveryDate?.toIso8601String(),
          'notes': ship['notes'],
        });
      }

      // -----------------------------------------------------------------------
      // ز. توليد 120 طلباً فردياً ومئات البنود التابعة لها + حركات الدفع
      // -----------------------------------------------------------------------
      final currencies = [
        AppConstants.currencyYer, // الأكثر شيوعاً محلياً
        AppConstants.currencySar, // التبادل مع السعودية
        AppConstants.currencyYer,
        AppConstants.currencyUsd, // الطاقة والشحن الخارجي
      ];

      final paymentStatuses = [
        AppConstants.paymentPrepaid,
        AppConstants.paymentDebt,
        AppConstants.paymentPartial,
        AppConstants.paymentCod,
      ];

      final orderStatuses = [
        AppConstants.orderStatusPending,
        AppConstants.orderStatusPurchased,
        AppConstants.orderStatusInCargo,
        AppConstants.orderStatusReady,
        AppConstants.orderStatusDelivered,
      ];

      final yemeniPaymentNotes = [
        'سداد عبر حوالة الكريمي إكسبريس رقم الحوالة موثق',
        'تم السداد نقداً عند استلام الطرد بفرزة النقل',
        'دفعة أولى عبر بنك القطيبي - المتبقي أجل لنهاية الشهر',
        'تحويل عبر النجم للصرافة فرع شارع تعز',
        'سداد بموجب سند قبض محلي عند التسليم يداً بيد',
        'حوالة عبر الامتياز إكسبريس مستلمة بالكامل',
        'عميل منتظم ومضمون - سداد فوري عند وصول الشحنة',
        'دفعة عربون بالريال السعودي والمتبقي عند استلام البضاعة',
      ];

      int globalItemCounter = 0;

      for (int i = 1; i <= 120; i++) {
        final orderId = 'demo_ord_$i';
        final orderNum = 'ORD-${2024}-${1000 + i}';

        // توزيع العملاء والشحنات دورياً وبشكل مترابط
        final customerIndex = (i - 1) % customerDefinitions.length;
        final customer = customerDefinitions[customerIndex];
        final customerId = 'demo_cust_${customerIndex + 1}';
        final customerName = customer['name']!;

        // العملة الخاصة بالطلب (غالبية يمني وسعودي مع شحنات دولار)
        final currency = currencies[(i % currencies.length)];

        // حالة الطلب وحالة الدفع
        final orderStatus = orderStatuses[i % orderStatuses.length];
        String paymentStatus;
        if (orderStatus == AppConstants.orderStatusDelivered) {
          paymentStatus = (i % 3 == 0)
              ? AppConstants.paymentDebt
              : AppConstants.paymentPrepaid;
        } else {
          paymentStatus = paymentStatuses[i % paymentStatuses.length];
        }

        // ربط الشحنة إذا كان الطلب في الشحن أو جاهز أو مسلّم
        String? shipmentId;
        if (orderStatus != AppConstants.orderStatusPending) {
          final shipIndex = (i % shipmentDefinitions.length);
          shipmentId = 'demo_ship_${shipIndex + 1}';
        }

        // التواريخ (أحدث 4 طلبات اليوم لضمان حيوية الصندوق اليومي وتقرير الشهر)
        final daysAgo = i >= 117 ? 0 : ((120 - i) ~/ 3) + 1;
        final createdAt = daysAgo == 0
            ? now.subtract(Duration(hours: (120 - i) + 1))
            : now.subtract(Duration(days: daysAgo));
        final expectedDeliveryDate = i >= 117
            ? now
            : now.add(Duration(days: (i % 7) + 1));
        final actualDeliveryDate =
            orderStatus == AppConstants.orderStatusDelivered
            ? now.subtract(Duration(days: (daysAgo ~/ 2)))
            : null;

        // ميعاد استحقاق الدين للطلبات الآجلة
        DateTime? debtDueDate;
        bool hasDebtReminder = false;
        if (paymentStatus == AppConstants.paymentDebt ||
            paymentStatus == AppConstants.paymentPartial) {
          hasDebtReminder = true;
          if (i % 4 == 0) {
            debtDueDate = now.subtract(Duration(days: (i % 5) + 1)); // متأخر
          } else if (i % 4 == 1) {
            debtDueDate = now; // يستحق اليوم
          } else {
            debtDueDate = now.add(Duration(days: (i % 14) + 2)); // قادم
          }
        }

        // بنود الطلب (2 إلى 4 بنود لكل طلب فردي)
        final itemsInThisOrder = 2 + (i % 3);
        double orderTotalSell = 0.0;
        double additionalCost = (i % 5 == 0)
            ? (currency == AppConstants.currencyYer
                ? 5000.0
                : (currency == AppConstants.currencySar ? 25.0 : 10.0))
            : 0.0;

        for (int itemIdx = 0; itemIdx < itemsInThisOrder; itemIdx++) {
          globalItemCounter++;
          final itemId = 'demo_item_$globalItemCounter';
          final catalogIdx = (i + itemIdx * 3) % itemCatalog.length;
          final catalogItem = itemCatalog[catalogIdx];
          final linkedProductId = catalogIndexToProductId[catalogIdx];

          final int quantity = (globalItemCounter % 3 == 0) ? 2 : 1;
          double costPrice;
          double sellPrice;

          if (currency == AppConstants.currencySar) {
            costPrice = catalogItem['costSar'] as double;
            sellPrice = catalogItem['sellSar'] as double;
          } else if (currency == AppConstants.currencyUsd) {
            costPrice = catalogItem['costUsd'] as double;
            sellPrice = catalogItem['sellUsd'] as double;
          } else {
            costPrice = catalogItem['costYer'] as double;
            sellPrice = catalogItem['sellYer'] as double;
          }

          orderTotalSell += (sellPrice * quantity);

          await txn.insert('order_items', {
            'id': itemId,
            'orderId': orderId,
            'productId': linkedProductId,
            'name': catalogItem['name'],
            'description': catalogItem['desc'],
            'quantity': quantity,
            'costPrice': costPrice,
            'sellPrice': sellPrice,
            'currency': currency,
            'photos': jsonEncode([]),
          });
        }

        // احتساب المبلغ المدفوع
        double paidAmount = 0.0;
        if (paymentStatus == AppConstants.paymentPrepaid) {
          paidAmount = orderTotalSell;
        } else if (paymentStatus == AppConstants.paymentPartial) {
          paidAmount = (orderTotalSell * 0.4).roundToDouble();
        } else if (paymentStatus == AppConstants.paymentCod &&
            orderStatus == AppConstants.orderStatusDelivered) {
          paidAmount = orderTotalSell;
        } else {
          paidAmount = 0.0;
        }

        final orderNote = yemeniPaymentNotes[i % yemeniPaymentNotes.length];

        await txn.insert('orders', {
          'id': orderId,
          'orderNumber': orderNum,
          'customerId': customerId,
          'customerName': customerName,
          'shipmentId': shipmentId,
          'paymentStatus': paymentStatus,
          'orderStatus': orderStatus,
          'createdAt': createdAt.toIso8601String(),
          'expectedDeliveryDate': expectedDeliveryDate.toIso8601String(),
          'actualDeliveryDate': actualDeliveryDate?.toIso8601String(),
          'debtDueDate': debtDueDate?.toIso8601String(),
          'hasDebtReminder': hasDebtReminder ? 1 : 0,
          'isSyncedWithCalendar': 0,
          'paidAmount': paidAmount,
          'additionalCost': additionalCost,
          'currency': currency,
          'notes': orderNote,
        });

        // تسجيل حركة الدفع في الصندوق (payment_transactions) للطلبات المدفوعة أو الجزئية
        if (paidAmount > 0) {
          await txn.insert('payment_transactions', {
            'id': 'demo_pay_$i',
            'orderId': orderId,
            'customerId': customerId,
            'amount': paidAmount,
            'currency': currency,
            'paymentMethod': (i % 2 == 0)
                ? AppConstants.paymentMethodCash
                : AppConstants.paymentMethodTransfer,
            'paidAt': createdAt.toIso8601String(),
            'notes': orderNum,
          });
        }
      }

      // -----------------------------------------------------------------------
      // ح. إدخال المصاريف المتنوعة (تشغيلية + شخصية + نثريات + دورية + موردين)
      // -----------------------------------------------------------------------
      final expenseDefinitions = <Map<String, dynamic>>[
        // مصاريف يومية / نثريات (قاعدة دورية + حركات حديثة)
        {
          'id': 'demo_exp_1',
          'title': 'مواصلات ونثريات توصيل يومية',
          'category': 'exp_cat_petty_cash',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 4500.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 2,
          'recurrence': AppConstants.expenseRecurrenceDaily,
          'isPettyCash': 1,
          'supplierId': 'demo_sup_6',
          'notes': 'نثريات توصيل يومية متكررة',
        },
        {
          'id': 'demo_exp_2',
          'title': 'توريد علب وأكياس تغليف أسبوعي',
          'category': 'exp_cat_packaging',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 32000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 8,
          'recurrence': AppConstants.expenseRecurrenceWeekly,
          'isPettyCash': 0,
          'supplierId': 'demo_sup_2',
          'notes': 'دفعة تغليف أسبوعية من مطبعة الخليج',
        },
        {
          'id': 'demo_exp_3',
          'title': 'إيجار الورشة والكهرباء والإنترنت',
          'category': 'exp_cat_other',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 85000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 3,
          'recurrence': AppConstants.expenseRecurrenceMonthly,
          'isPettyCash': 0,
          'supplierId': null,
          'notes': 'التزام تشغيلي شهري ثابت',
        },
        // مشتريات مواد خام وبضاعة مرتبطة بالموردين
        {
          'id': 'demo_exp_4',
          'title': 'شراء حبوب بن يافعي وهيل وتوابل',
          'category': 'exp_cat_materials',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 145000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 1,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': 'demo_sup_1',
          'notes': 'فاتورة توريد خامات للتحميص',
        },
        {
          'id': 'demo_exp_5',
          'title': 'شراء خشب عود ودهن عود كمبودي',
          'category': 'exp_cat_materials',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 210000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 4,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': 'demo_sup_4',
          'notes': 'مواد خام لطبخة البخور العدني',
        },
        {
          'id': 'demo_exp_6',
          'title': 'توريد دفعة عسل دوعني وشبواني بالجملة',
          'category': 'exp_cat_materials',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 320000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 6,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': 'demo_sup_3',
          'notes': 'مخزون إعادة بيع للعسل الملكي',
        },
        {
          'id': 'demo_exp_7',
          'title': 'طباعة استيكرات وعلب هدايا مخصصة',
          'category': 'exp_cat_packaging',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 48000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 5,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': 'demo_sup_2',
          'notes': 'تغليف خاص بطلبات المناسبات',
        },
        {
          'id': 'demo_exp_8',
          'title': 'تسوية مشاوير مندوب التوصيل اليوم',
          'category': 'exp_cat_delivery',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 12000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 0,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': 'demo_sup_6',
          'notes': 'توصيل طلبات اليوم داخل المدينة',
        },
        {
          'id': 'demo_exp_9',
          'title': 'حملة إعلانية ممولة على واتساب وإنستغرام',
          'category': 'exp_cat_marketing',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 35000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 3,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': null,
          'notes': 'ترويج عروض البخور والعسل',
        },
        {
          'id': 'demo_exp_10',
          'title': 'نثريات أكياس وقرطاسية وشاي للضيوف',
          'category': 'exp_cat_petty_cash',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 6500.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 0,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 1,
          'supplierId': null,
          'notes': 'نثريات يومية من الصندوق',
        },
        {
          'id': 'demo_exp_11',
          'title': 'شراء شيلان ومعاوز جاهزة للموسم',
          'category': 'exp_cat_materials',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 175000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 7,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': 'demo_sup_5',
          'notes': 'بضاعة إعادة بيع من مركز النخبة',
        },
        {
          'id': 'demo_exp_12',
          'title': 'نثريات غاز ووقود وتغليف سريع',
          'category': 'exp_cat_petty_cash',
          'expenseType': AppConstants.expenseTypeBusiness,
          'amount': 9000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 2,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 1,
          'supplierId': null,
          'notes': 'صرف سريع من العهدة',
        },
        // مسحوبات شخصية (للبيت - لا تنقص صافي ربح المشروع)
        {
          'id': 'demo_exp_13',
          'title': 'مصروف البيت الأسبوعي',
          'category': 'exp_cat_other',
          'expenseType': AppConstants.expenseTypePersonal,
          'amount': 45000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 0,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': null,
          'notes': 'سحب شخصي للأسرة',
        },
        {
          'id': 'demo_exp_14',
          'title': 'مستلزمات منزلية ومصاريف شخصية',
          'category': 'exp_cat_other',
          'expenseType': AppConstants.expenseTypePersonal,
          'amount': 60000.0,
          'currency': AppConstants.currencyYer,
          'daysAgo': 6,
          'recurrence': AppConstants.expenseRecurrenceOnce,
          'isPettyCash': 0,
          'supplierId': null,
          'notes': 'سحب شخصي من الأرباح',
        },
      ];

      for (final exp in expenseDefinitions) {
        final daysAgo = exp['daysAgo'] as int;
        final expDate = now.subtract(Duration(days: daysAgo));
        await txn.insert('expenses', {
          'id': exp['id'],
          'title': exp['title'],
          'category': exp['category'],
          'expenseType': exp['expenseType'],
          'amount': exp['amount'],
          'currency': exp['currency'],
          'expenseDate': expDate.toIso8601String(),
          'notes': exp['notes'],
          'recurrence': exp['recurrence'],
          'isPettyCash': exp['isPettyCash'],
          'supplierId': exp['supplierId'],
          'receiptPhotoPath': null,
          'parentRuleId': null,
          'createdAt': expDate.toIso8601String(),
        });
      }

      // -----------------------------------------------------------------------
      // ط. إدخال إغلاقين يوميين للصندوق (الأمس وقبل الأمس) دون المساس بأي إغلاق حقيقي
      // -----------------------------------------------------------------------
      final yesterday = now.subtract(const Duration(days: 1));
      final twoDaysAgo = now.subtract(const Duration(days: 2));

      await txn.insert(
        'daily_closings',
        {
          'id': 'demo_close_1',
          'closingDate': formatDateOnly(yesterday),
          'cashInYer': 420000.0,
          'businessExpensesYer': 145000.0,
          'personalDrawingsYer': 25000.0,
          'ordersCount': 6,
          'notes': 'إغلاق يومي تجريبي — مطابقة الدرج تماماً',
          'closedAt': yesterday.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.insert(
        'daily_closings',
        {
          'id': 'demo_close_2',
          'closingDate': formatDateOnly(twoDaysAgo),
          'cashInYer': 315000.0,
          'businessExpensesYer': 52000.0,
          'personalDrawingsYer': 15000.0,
          'ordersCount': 5,
          'notes': 'إغلاق يومي تجريبي — يوم عمل ممتاز',
          'closedAt': twoDaysAgo.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });

    _notifyAllDomains();
    return await getDemoDataStats();
  }
}
