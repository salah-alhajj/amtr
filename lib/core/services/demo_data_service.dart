import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../constants.dart';
import '../database/app_database.dart';

/// إحصائيات وسجلات البيانات التجريبية المتوفرة في قاعدة البيانات
class DemoDataStats {
  final int customersCount;
  final int shipmentsCount;
  final int ordersCount;
  final int itemsCount;

  const DemoDataStats({
    this.customersCount = 0,
    this.shipmentsCount = 0,
    this.ordersCount = 0,
    this.itemsCount = 0,
  });

  int get totalRecords =>
      customersCount + shipmentsCount + ordersCount + itemsCount;
  bool get hasDemoData => totalRecords > 0;
}

/// خدمة توليد وحذف الداتا التجريبية والتدريبية للنظام
/// تنشئ مئات السجلات الواقعية المستوحاة بالكامل من البيئة والتجارة والمحافظات والأسواق اليمنية
/// (عملاء يمنيون، فرزات وشركات نقل محلية، سلع وتراث يمني، منظومات طاقة، عسل وبن وبخور، حوالات الكريمي والنجم)
/// وتتيح إزالتها كلياً بنقرة واحدة دون المساس بأي بيانات حقيقية أخرى.
class DemoDataService {
  static final DemoDataService instance = DemoDataService._init();
  DemoDataService._init();

  /// جلب إحصائيات البيانات التجريبية الحالية في قاعدة البيانات
  Future<DemoDataStats> getDemoDataStats() async {
    final db = await AppDatabase.instance.database;
    final cCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM customers WHERE id LIKE 'demo_%'",
          ),
        ) ??
        0;
    final sCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM shipments WHERE id LIKE 'demo_%'",
          ),
        ) ??
        0;
    final oCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM orders WHERE id LIKE 'demo_%'",
          ),
        ) ??
        0;
    final iCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM order_items WHERE id LIKE 'demo_%'",
          ),
        ) ??
        0;

    return DemoDataStats(
      customersCount: cCount,
      shipmentsCount: sCount,
      ordersCount: oCount,
      itemsCount: iCount,
    );
  }

  /// حذف كافة البيانات التجريبية من قاعدة البيانات بشكل آمن تماماً
  Future<int> removeDemoData() async {
    final db = await AppDatabase.instance.database;
    int totalDeleted = 0;

    await db.transaction((txn) async {
      final itemsDeleted = await txn.delete(
        'order_items',
        where: 'id LIKE ?',
        whereArgs: ['demo_%'],
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

      totalDeleted =
          itemsDeleted + ordersDeleted + shipmentsDeleted + customersDeleted;
    });

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
    await db.transaction((txn) async {
      // أ. إدخال العملاء
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
          'createdAt': createdAt.toIso8601String(),
        });
      }

      // ب. إدخال الشحنات المجمعة
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

      // ج. توليد 120 طلباً فردياً ومئات البنود التابعة لها
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

        // التواريخ
        final daysAgo = (120 - i) ~/ 3;
        final createdAt = now.subtract(Duration(days: daysAgo + 1));
        final expectedDeliveryDate = now.add(Duration(days: (i % 7) + 1));
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
          final catalogItem =
              itemCatalog[(i + itemIdx * 3) % itemCatalog.length];

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
      }
    });

    return await getDemoDataStats();
  }
}
