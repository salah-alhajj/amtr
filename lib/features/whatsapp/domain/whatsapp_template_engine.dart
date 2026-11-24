import '../../../core/constants.dart';
import '../../../core/localization/localization.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../models/individual_order.dart';
import '../../../models/product.dart';
import '../../../models/whatsapp_template.dart';

/// محرك قوالب رسائل واتساب المُلطّفة وبناء المنيو المصنّف
class WhatsAppTemplateEngine {
  WhatsAppTemplateEngine._();

  static const String typeConfirmDeposit = 'confirm_deposit';
  static const String typeReady = 'ready';
  static const String typeReminder = 'reminder';
  static const String typeThanks = 'thanks';

  static const String toneWarm = 'warm';
  static const String tonePolite = 'polite';
  static const String toneFormal = 'formal';

  static const List<String> templateTypes = [
    typeConfirmDeposit,
    typeReady,
    typeReminder,
    typeThanks,
  ];

  static const List<String> reminderTones = [
    toneWarm,
    tonePolite,
    toneFormal,
  ];

  /// القوالب الافتراضية الدافئة لجميع الأنواع والنبرات
  static List<WhatsAppTemplate> get defaultTemplates => [
        const WhatsAppTemplate(
          id: 'tpl_confirm_deposit_warm',
          type: typeConfirmDeposit,
          tone: toneWarm,
          title: 'تأكيد الطلب والعربون',
          body: '*{business_name}*\n'
              'أهلاً وسهلاً *{customer}*، أسعد الله أوقاتكم بكل خير.\n'
              'تم استلام وتأكيد طلبكم رقم *#{order_number}* بكل سرور:\n'
              '{items}\n'
              '• الإجمالي: {total}\n'
              '• الواصل: {paid}\n'
              '• المتبقي عند التسليم: {remaining}\n'
              'نشكركم على ثقتكم الغالية، وسنوافيكم فور جهوزية الطلب.\n'
              '{footer_note}\n'
              '{business_phone}',
          isDefault: true,
        ),
        const WhatsAppTemplate(
          id: 'tpl_ready_warm',
          type: typeReady,
          tone: toneWarm,
          title: 'طلبك جاهز',
          body: '*{business_name}*\n'
              'مرحباً *{customer}*، بشرى سارة!\n'
              'طلبكم رقم *#{order_number}* أصبح جاهزاً الآن.\n'
              '{items}\n'
              '• الإجمالي: {total}\n'
              '• المتبقي: {remaining}\n'
              'يسعدنا تواصلكم لتنسيق الاستلام أو التوصيل في الوقت المناسب لكم.\n'
              '{footer_note}\n'
              '{business_phone}',
          isDefault: true,
        ),
        // نبرة ودّية للأقارب والمعارف — خالية تماماً من كلمة «دين»
        const WhatsAppTemplate(
          id: 'tpl_reminder_warm',
          type: typeReminder,
          tone: toneWarm,
          title: 'تذكير لطيف (ودّي للأقارب)',
          body: '*{business_name}*\n'
              'السلام عليكم *{customer}*، أتمنى أن تكونوا بأتم الصحة والعافية.\n'
              'أحببت فقط مشاركتكم ملخص طلبكم رقم *#{order_number}* للمتابعة:\n'
              '• إجمالي الطلب: {total}\n'
              '• المبلغ الواصل: {paid}\n'
              '• المبلغ المتبقي: *{remaining}*\n'
              'لا تشيلوا هم، متى ما تيسرت أموركم يسعدنا استلام المتبقي.\n'
              'دمتم بخير وبارك الله فيكم.\n'
              '{business_phone}',
          isDefault: true,
        ),
        const WhatsAppTemplate(
          id: 'tpl_reminder_polite',
          type: typeReminder,
          tone: tonePolite,
          title: 'تذكير لطيف ومهني',
          body: '*{business_name}*\n'
              'تحية طيبة *{customer}*،\n'
              'نود تذكيركم بلطف بالمبلغ المتبقي على طلبكم رقم *#{order_number}*:\n'
              '• الإجمالي: {total}\n'
              '• المسدد: {paid}\n'
              '• المتبقي: *{remaining}*\n'
              'نشكر لكم حسن تعاونكم وتعاملكم الراقي معنا.\n'
              '{footer_note}\n'
              '{business_phone}',
          isDefault: true,
        ),
        const WhatsAppTemplate(
          id: 'tpl_reminder_formal',
          type: typeReminder,
          tone: toneFormal,
          title: 'تذكير رسمي مختصر',
          body: '*{business_name}*\n'
              'الأخ/الأخت *{customer}*،\n'
              'تذكير بخصوص الطلب رقم *#{order_number}*:\n'
              'الإجمالي: {total} | المسدد: {paid} | المتبقي: *{remaining}*.\n'
              'يرجى التكرم بسداد المبلغ المتبقي عند الإمكان، مع خالص الشكر.\n'
              '{business_phone}',
          isDefault: true,
        ),
        const WhatsAppTemplate(
          id: 'tpl_thanks_warm',
          type: typeThanks,
          tone: toneWarm,
          title: 'شكر بعد السداد',
          body: '*{business_name}*\n'
              'شكراً جزيلاً *{customer}* على سداد كامل مبلغ الطلب رقم *#{order_number}* ({total}).\n'
              'تشرفت جداً بخدمتكم، وأتمنى أن يكون الطلب قد نال إعجابكم.\n'
              'يسعدنا دائماً لقاؤكم في طلبات قادمة!\n'
              '{footer_note}\n'
              '{business_phone}',
          isDefault: true,
        ),
      ];

  /// إرجاع نص القالب الافتراضي حسب النوع والنبرة
  static String getDefaultBody(String type, {String tone = toneWarm}) {
    if (type == typeReminder) {
      final match = defaultTemplates.where(
        (t) => t.type == typeReminder && t.tone == tone,
      );
      if (match.isNotEmpty) return match.first.body;
    }
    final byType = defaultTemplates.where((t) => t.type == type);
    if (byType.isNotEmpty) return byType.first.body;
    return defaultTemplates.first.body;
  }

  /// تعبئة قالب رسالة طلب بالمتغيرات الفعلية
  static String renderOrderMessage({
    required IndividualOrder order,
    required String type,
    String tone = toneWarm,
    String? customBody,
    String? customerName,
  }) {
    final prefs = PreferencesService.instance;
    final businessName = prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final footerNote = prefs.getInvoiceFooterNote().trim();
    final symbol = AppConstants.getCurrencySymbol(order.currency);

    final resolvedCustomer = (customerName != null && customerName.trim().isNotEmpty)
        ? customerName.trim()
        : (order.customerName != null && order.customerName!.trim().isNotEmpty)
            ? order.customerName!.trim()
            : 'عميلنا العزيز';

    final itemsText = _formatOrderItems(order, symbol);
    final totalText = '${order.totalSellPrice.toStringAsFixed(0)} $symbol';
    final paidText = '${order.paidAmount.toStringAsFixed(0)} $symbol';
    final remainingText = '${order.remainingDebt.toStringAsFixed(0)} $symbol';

    final template = (customBody != null && customBody.trim().isNotEmpty)
        ? customBody
        : getDefaultBody(type, tone: tone);

    var rendered = template
        .replaceAll('{customer}', resolvedCustomer)
        .replaceAll('{order_number}', order.orderNumber)
        .replaceAll('{items}', itemsText)
        .replaceAll('{total}', totalText)
        .replaceAll('{paid}', paidText)
        .replaceAll('{remaining}', remainingText)
        .replaceAll('{business_name}', businessName)
        .replaceAll('{business_phone}', businessPhone.isNotEmpty ? 'للتواصل: $businessPhone' : '')
        .replaceAll('{footer_note}', footerNote);

    // تنظيف الأسطر الفارغة المتكررة الناتجة عن حقول اختيارية فارغة
    final cleanedLines = rendered
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line != '**')
        .toList();

    final buffer = StringBuffer();
    bool lastWasEmpty = true;
    for (final line in cleanedLines) {
      if (line.trim().isEmpty) {
        if (!lastWasEmpty) {
          buffer.writeln();
          lastWasEmpty = true;
        }
      } else {
        buffer.writeln(line);
        lastWasEmpty = false;
      }
    }

    return buffer.toString().trim();
  }

  static String _formatOrderItems(IndividualOrder order, String symbol) {
    if (order.items.isEmpty) return '• (بدون أصناف مسجلة)';
    final lines = <String>[];
    for (int i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final pricePart = item.totalSell != null
          ? ' — ${item.totalSell!.toStringAsFixed(0)} $symbol'
          : '';
      lines.add('${i + 1}. ${item.name} × ${item.quantity}$pricePart');
    }
    return lines.join('\n');
  }

  /// بناء نص المنيو / الكتالوج المصنّف للمشاركة عبر واتساب
  /// يستبعد الأصناف النافدة من المخزون تلقائياً (عند [excludeOutOfStock])
  /// ويُذيّل المنيو بنموذج طلب سريع جاهز للنسخ والتعبئة ليتعرف عليه محلل طلبات واتساب فوراً
  static String buildCategorizedCatalogText(
    List<Product> products, {
    bool excludeOutOfStock = true,
    bool includeQuickOrderFooter = true,
  }) {
    final activeProducts = products
        .where((p) => p.isActive && (!excludeOutOfStock || !p.isOutOfStock))
        .toList();
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final businessName = prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();

    final buffer = StringBuffer();
    if (businessName.isNotEmpty) {
      buffer.writeln('*$businessName*');
    } else {
      buffer.writeln('*${'products_catalog_title'.i18n()}*');
    }
    buffer.writeln('--------------------------------');

    if (activeProducts.isEmpty) {
      buffer.writeln('products_empty_title'.i18n());
    } else {
      final grouped = <String, List<Product>>{};
      for (final product in activeProducts) {
        grouped.putIfAbsent(product.category, () => []).add(product);
      }

      final categories = grouped.keys.toList();
      for (int cIdx = 0; cIdx < categories.length; cIdx++) {
        final categoryKey = categories[cIdx];
        final categoryItems = grouped[categoryKey]!;
        buffer.writeln('*[${categoryKey.i18n()}]*');
        for (int i = 0; i < categoryItems.length; i++) {
          final p = categoryItems[i];
          final price = cs.formatAmount(p.sellPrice, currencyCode: p.currency);
          final stockSuffix = (!excludeOutOfStock && p.isOutOfStock)
              ? ' — (نفد المخزون)'
              : '';
          buffer.writeln('${i + 1}. *${p.name}* (${p.unit}) — $price$stockSuffix');
        }
        if (cIdx < categories.length - 1) {
          buffer.writeln();
        }
      }
    }

    buffer.writeln('--------------------------------');
    if (includeQuickOrderFooter && activeProducts.isNotEmpty) {
      buffer.writeln('للطلب السريع، انسخ وعبّئ النموذج التالي وأرسله لنا:');
      buffer.writeln('الاسم: ');
      buffer.writeln('الجوال: ');
      buffer.writeln('الطلب والكمية: ');
      buffer.writeln('الحي أو الاستلام: ');
      buffer.writeln('--------------------------------');
    }

    if (businessPhone.isNotEmpty) {
      buffer.writeln('${'business_phone_label'.i18n()}: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء رسالة طلب توريد / إعادة تعبئة مواد خام بلمسة واحدة لإرسالها للمورّد عبر واتساب
  static String buildSupplierRestockMessage({
    required String supplierName,
    required List<String> itemLines,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedSupplier = supplierName.trim().isNotEmpty
        ? supplierName.trim()
        : 'مورّدنا الكريم';

    final cleanedItems = itemLines
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('السلام عليكم *$resolvedSupplier*، أسعد الله أوقاتكم بكل خير.');
    buffer.writeln('نرجو منكم توفير وتجهيز طلبية التوريد التالية:');
    buffer.writeln('--------------------------------');

    if (cleanedItems.isEmpty) {
      buffer.writeln('• (لم يتم تحديد أصناف)');
    } else {
      for (int i = 0; i < cleanedItems.length; i++) {
        buffer.writeln('${i + 1}. ${cleanedItems[i]}');
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('يرجى تأكيد التوفر وإجمالي التكلفة وموعد التسليم، شاكرين حسن تعاونكم.');
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء رسالة قائمة مشتريات المواد الخام اليومية للمشاركة عبر واتساب
  static String buildShoppingListMessage({
    required List<String> groupedLines,
    String? dateLabel,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final cleanedDate = dateLabel?.trim() ?? '';

    final cleanedLines = groupedLines
        .map((e) => e.trimRight())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    if (cleanedDate.isNotEmpty) {
      buffer.writeln('*قائمة مشتريات المواد الخام* — $cleanedDate');
    } else {
      buffer.writeln('*قائمة مشتريات المواد الخام*');
    }
    buffer.writeln('--------------------------------');

    if (cleanedLines.isEmpty) {
      buffer.writeln('• (لا توجد مواد مطلوبة حالياً)');
    } else {
      for (final line in cleanedLines) {
        buffer.writeln(line);
      }
    }

    buffer.writeln('--------------------------------');
    return buffer.toString().trim();
  }

  /// بناء رسالة سند دفعة سداد لمورّد مع الرصيد المتبقي
  static String buildSupplierPaymentReceiptMessage({
    required String supplierName,
    required double paidAmount,
    required String currency,
    required double remainingBalanceYer,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedSupplier = supplierName.trim().isNotEmpty
        ? supplierName.trim()
        : 'مورّدنا الكريم';

    final paidText = cs.formatAmount(paidAmount, currencyCode: currency);
    final remainingText = cs.formatAmount(
      remainingBalanceYer,
      currencyCode: AppConstants.currencyYer,
    );

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('*سند دفعة لمورّد*');
    buffer.writeln('السلام عليكم *$resolvedSupplier*، أسعد الله أوقاتكم بكل خير.');
    buffer.writeln('تم تسجيل دفعة سداد لحسابكم بالتفاصيل التالية:');
    buffer.writeln('--------------------------------');
    buffer.writeln('• المبلغ المدفوع: *$paidText*');
    buffer.writeln('• الرصيد المتبقي: *$remainingText*');
    buffer.writeln('--------------------------------');
    buffer.writeln('شاكرين حسن تعاونكم وتعاملكم الطيب معنا.');
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء رسالة كشف حساب مختصر للمورّد للمراجعة والمطابقة
  static String buildSupplierStatementMessage({
    required String supplierName,
    required double totalPurchasesYer,
    required double totalPaymentsYer,
    required double balanceYer,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedSupplier = supplierName.trim().isNotEmpty
        ? supplierName.trim()
        : 'مورّدنا الكريم';

    final purchasesText = cs.formatAmount(
      totalPurchasesYer,
      currencyCode: AppConstants.currencyYer,
    );
    final paymentsText = cs.formatAmount(
      totalPaymentsYer,
      currencyCode: AppConstants.currencyYer,
    );
    final balanceText = cs.formatAmount(
      balanceYer,
      currencyCode: AppConstants.currencyYer,
    );

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('*كشف حساب مورّد*');
    buffer.writeln('السلام عليكم *$resolvedSupplier*،');
    buffer.writeln('نشارككم ملخص كشف الحساب الحالي للمراجعة والمطابقة:');
    buffer.writeln('--------------------------------');
    buffer.writeln('• إجمالي المشتريات: $purchasesText');
    buffer.writeln('• إجمالي المدفوعات: $paymentsText');
    buffer.writeln('• الرصيد المتبقي: *$balanceText*');
    buffer.writeln('--------------------------------');
    buffer.writeln('يرجى إشعارنا في حال وجود أي ملاحظة، شاكرين حسن تعاونكم.');
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء كشف تسليم الطلبات لمندوب التوصيل مع تفاصيل التحصيل والعناوين
  static String buildCourierDispatchSheetMessage({
    required String courierName,
    required List<IndividualOrder> orders,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedCourier = courierName.trim().isNotEmpty
        ? courierName.trim()
        : 'المندوب';

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('*كشف تسليم طلبات للمندوب* — *$resolvedCourier*');
    buffer.writeln('عدد الطلبات: *${orders.length}*');
    buffer.writeln('--------------------------------');

    if (orders.isEmpty) {
      buffer.writeln('• (لا توجد طلبات مسندة حالياً)');
    } else {
      double totalCollectYer = 0.0;
      for (int i = 0; i < orders.length; i++) {
        final order = orders[i];
        final customerLabel =
            (order.customerName != null && order.customerName!.trim().isNotEmpty)
                ? order.customerName!.trim()
                : 'عميل';
        final dueAmount = order.remainingDebt;
        totalCollectYer += cs.toBaseYer(dueAmount, order.currency);
        final dueLabel = dueAmount > 0
            ? 'المطلوب تحصيله: *${cs.formatAmount(dueAmount, currencyCode: order.currency)}*'
            : 'مدفوع مسبقاً';

        buffer.writeln('${i + 1}. طلب *#${order.orderNumber}* — $customerLabel');
        if (order.deliveryAddress != null &&
            order.deliveryAddress!.trim().isNotEmpty) {
          buffer.writeln('   العنوان: ${order.deliveryAddress!.trim()}');
        }
        if (order.items.isNotEmpty) {
          final summary = order.items
              .map((it) => '${it.name} × ${it.quantity}')
              .join('، ');
          buffer.writeln('   الأصناف: $summary');
        }
        buffer.writeln('   $dueLabel');
        if (order.notes != null && order.notes!.trim().isNotEmpty) {
          buffer.writeln('   ملاحظة: ${order.notes!.trim()}');
        }
      }
      buffer.writeln('--------------------------------');
      buffer.writeln(
        '• إجمالي التحصيل المطلوب: *${cs.formatAmount(totalCollectYer, currencyCode: AppConstants.currencyYer)}*',
      );
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('يرجى تأكيد الاستلام وموافاتنا بحالة كل طلب أولاً بأول.');
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء سند تسوية وتصفية حساب مندوب التوصيل
  static String buildCourierSettlementReceiptMessage({
    required String courierName,
    required int deliveredCount,
    required int returnedCount,
    required double collectedCashYer,
    required double deliveryFeesYer,
    required double returnFeesYer,
    required double netRemittedYer,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedCourier = courierName.trim().isNotEmpty
        ? courierName.trim()
        : 'المندوب';

    final collectedText = cs.formatAmount(
      collectedCashYer,
      currencyCode: AppConstants.currencyYer,
    );
    final deliveryFeesText = cs.formatAmount(
      deliveryFeesYer,
      currencyCode: AppConstants.currencyYer,
    );
    final returnFeesText = cs.formatAmount(
      returnFeesYer,
      currencyCode: AppConstants.currencyYer,
    );
    final netRemittedText = cs.formatAmount(
      netRemittedYer,
      currencyCode: AppConstants.currencyYer,
    );

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('*سند تسوية وتصفية حساب مندوب*');
    buffer.writeln('المندوب: *$resolvedCourier*');
    buffer.writeln('--------------------------------');
    buffer.writeln('• الطلبات المسلّمة: *$deliveredCount*');
    buffer.writeln('• الطلبات المرتجعة: *$returnedCount*');
    buffer.writeln('• إجمالي التحصيل النقدي: $collectedText');
    buffer.writeln('• أجور التوصيل: $deliveryFeesText');
    if (returnFeesYer > 0) {
      buffer.writeln('• رسوم المرتجعات: $returnFeesText');
    }
    buffer.writeln('• الصافي المسلّم للإدارة: *$netRemittedText*');
    buffer.writeln('--------------------------------');
    buffer.writeln('تمت التسوية والتصفية بنجاح، شكراً لجهودكم وتعاونكم.');
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء رسالة تأكيد الدفع عند الاستلام قبل خروج المندوب لتقليل المرتجعات
  static String buildPreDispatchCodConfirmMessage(
    IndividualOrder order, {
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedCustomer =
        (order.customerName != null && order.customerName!.trim().isNotEmpty)
            ? order.customerName!.trim()
            : 'عميلنا العزيز';

    final amountDue =
        order.remainingDebt > 0 ? order.remainingDebt : order.totalSellPrice;
    final amountText = cs.formatAmount(amountDue, currencyCode: order.currency);

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('السلام عليكم *$resolvedCustomer*، أسعد الله أوقاتكم بكل خير.');
    buffer.writeln(
      'طلبكم رقم *#${order.orderNumber}* جاهز الآن للخروج مع مندوب التوصيل.',
    );
    if (order.items.isNotEmpty) {
      buffer.writeln('--------------------------------');
      for (int i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        final pricePart = item.totalSell != null
            ? ' — ${cs.formatAmount(item.totalSell!, currencyCode: item.currency)}'
            : '';
        buffer.writeln('${i + 1}. ${item.name} × ${item.quantity}$pricePart');
      }
      buffer.writeln('--------------------------------');
    }
    if (order.deliveryAddress != null &&
        order.deliveryAddress!.trim().isNotEmpty) {
      buffer.writeln('• عنوان التوصيل: ${order.deliveryAddress!.trim()}');
    }
    buffer.writeln('• المبلغ المطلوب عند الاستلام: *$amountText*');
    buffer.writeln(
      'يرجى الرد بكلمة *تأكيد* لاعتماد إرسال المندوب فوراً وتحديد الوقت المناسب لاستلامكم.',
    );
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء رسالة تذكير ذكي ولطيف لإعادة الطلب عند اقتراب انتهاء دورة الاستهلاك
  static String buildSmartReorderNudgeMessage({
    required String customerName,
    required String productName,
    required int daysSinceLastOrder,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedCustomer = customerName.trim().isNotEmpty
        ? customerName.trim()
        : 'عميلنا العزيز';
    final resolvedProduct = productName.trim().isNotEmpty
        ? productName.trim()
        : 'طلبكم المعتاد';

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln(
      'أهلاً وسهلاً *$resolvedCustomer*، أتمنى أن تكونوا بأتم الصحة والعافية.',
    );
    buffer.writeln(
      'مرّ *$daysSinceLastOrder* يوماً منذ آخر طلب لكم من *$resolvedProduct*، وأحببنا أن نطمئن إن كان أوشك على الانتهاء.',
    );
    buffer.writeln(
      'يسعدنا تجهيز طلب جديد لكم بنفس الجودة والعناية متى ما رغبتم، فقط أرسلوا لنا ردكم وسنجهزه لكم بكل سرور.',
    );
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  static String _formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// بناء رسالة اعتذار لطيفة عند اكتمال الطاقة الاستيعابية لليوم واقتراح أقرب موعد متاح
  static String buildCapacityFullApologyMessage({
    required DateTime fullDate,
    DateTime? nextAvailableDate,
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final fullDateText = _formatIsoDate(fullDate);

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('أهلاً وسهلاً بكم، أسعد الله أوقاتكم بكل خير.');
    buffer.writeln(
      'نعتذر منكم بكل لطف، فقد اكتملت طاقة استقبال الطلبات لدينا ليوم *$fullDateText* حرصاً على تقديم أعلى جودة.',
    );
    if (nextAvailableDate != null) {
      final nextDateText = _formatIsoDate(nextAvailableDate);
      buffer.writeln(
        'أقرب موعد متاح لاستقبال طلبكم هو يوم *$nextDateText*، ويسعدنا جداً حجزه وتجهيزه لكم بكل عناية.',
      );
    } else {
      buffer.writeln(
        'يسعدنا حجز طلبكم في أقرب موعد متاح قادم، فقط أخبرونا باليوم المناسب لكم وسنؤكد الحجز فوراً.',
      );
    }
    buffer.writeln('نشكر تفهّمكم وثقتكم الغالية بنا.');
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }

  /// بناء رسالة تذكير لطيفة بإتمام العربون لتأكيد الطلب والبدء بالتجهيز
  static String buildDepositReminderMessage(
    IndividualOrder order, {
    String? businessName,
  }) {
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final resolvedBusiness =
        (businessName != null && businessName.trim().isNotEmpty)
            ? businessName.trim()
            : prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final resolvedCustomer =
        (order.customerName != null && order.customerName!.trim().isNotEmpty)
            ? order.customerName!.trim()
            : 'عميلنا العزيز';

    final depositRequired =
        order.depositAmount > 0 ? order.depositAmount : order.totalSellPrice;
    final remainingDeposit = (depositRequired - order.paidAmount) > 0
        ? (depositRequired - order.paidAmount)
        : 0.0;

    final totalText =
        cs.formatAmount(order.totalSellPrice, currencyCode: order.currency);
    final depositText =
        cs.formatAmount(depositRequired, currencyCode: order.currency);
    final paidText =
        cs.formatAmount(order.paidAmount, currencyCode: order.currency);
    final remainingDepositText =
        cs.formatAmount(remainingDeposit, currencyCode: order.currency);

    final buffer = StringBuffer();
    if (resolvedBusiness.isNotEmpty) {
      buffer.writeln('*$resolvedBusiness*');
    }
    buffer.writeln('السلام عليكم *$resolvedCustomer*، أسعد الله أوقاتكم بكل خير.');
    buffer.writeln(
      'نود تذكيركم بلطف بإتمام عربون طلبكم رقم *#${order.orderNumber}* لتأكيد الحجز والبدء في التجهيز:',
    );
    buffer.writeln('--------------------------------');
    buffer.writeln('• إجمالي الطلب: $totalText');
    buffer.writeln('• قيمة العربون المطلوب: *$depositText*');
    if (order.paidAmount > 0) {
      buffer.writeln('• المبلغ الواصل: $paidText');
      if (remainingDeposit > 0) {
        buffer.writeln('• المتبقي لاستكمال العربون: *$remainingDepositText*');
      }
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(
      'فور استلام العربون سيتم اعتماد طلبكم والبدء بتجهيزه بكل عناية، شاكرين ثقتكم وتعاونكم.',
    );
    if (businessPhone.isNotEmpty) {
      buffer.writeln('للتواصل: $businessPhone');
    }

    return buffer.toString().trim();
  }
}
