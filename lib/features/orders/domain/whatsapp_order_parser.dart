import '../../../core/constants.dart';
import '../../../core/utils/yemen_phone_helper.dart';
import '../../../models/product.dart';

/// سطر صنف مُستخرج من رسالة واتساب ومطابق لمنتج في الكتالوج
class ParsedOrderLine {
  final Product product;
  final int quantity;

  const ParsedOrderLine({
    required this.product,
    required this.quantity,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedOrderLine &&
        other.product.id == product.id &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(product.id, quantity);

  @override
  String toString() => 'ParsedOrderLine(${product.name} × $quantity)';
}

/// نتيجة تحليل رسالة طلب واردة من واتساب (عمل محلي 100% بدون إنترنت)
class ParsedWhatsAppOrder {
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;

  /// نوع التسليم المستنتج: `pickup` أو `delivery` أو `null` إذا لم يُذكر
  final String? deliveryType;
  final List<ParsedOrderLine> matchedItems;
  final String? rawNotes;

  const ParsedWhatsAppOrder({
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.deliveryType,
    this.matchedItems = const [],
    this.rawNotes,
  });

  bool get hasItems => matchedItems.isNotEmpty;

  bool get hasAnyData =>
      customerName != null ||
      customerPhone != null ||
      deliveryAddress != null ||
      deliveryType != null ||
      matchedItems.isNotEmpty ||
      rawNotes != null;

  bool get isEmpty => !hasAnyData;
}

/// محلل رسائل طلبات واتساب باللغتين العربية والإنجليزية بدون اتصال بالإنترنت
class WhatsAppOrderParser {
  WhatsAppOrderParser._();

  // إزالة علامات الاتجاه الخفية التي يضيفها واتساب حول الأرقام والنصوص
  static final RegExp _bidiMarksRegex =
      RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');

  // التشكيل والتطويل العربي
  static final RegExp _arabicDiacriticsRegex =
      RegExp(r'[\u064B-\u065F\u0670\u0640]');

  // التحقق من وجود حروف عربية أو لاتينية للحدود اللفظية
  static final RegExp _letterRegex = RegExp(r'[\u0621-\u064A\u0671-\u06D3a-zA-Z]');

  // ترويسات النموذج الجاهز التي يجب تجاهلها كملاحظات إذا نسخها العميل
  static const List<String> _ignoredBoilerplatePhrases = [
    'للطلب السريع',
    'انسخ وعب',
    'نموذج الطلب',
    'quick order',
    'copy and fill',
  ];

  // عبارات التحية الشائعة (لا تُعد ملاحظات طلب)
  static const List<String> _greetingOnlyPhrases = [
    'السلام عليكم',
    'السلام عليكم ورحمه الله',
    'السلام عليكم ورحمه الله وبركاته',
    'وعليكم السلام',
    'مرحبا',
    'اهلا',
    'هلا',
    'مساء الخير',
    'صباح الخير',
    'لو سمحت',
    'لو سمحتي',
    'لو سمحتوا',
    'يعطيك العافيه',
    'يعطيكم العافيه',
    'شكرا',
    'مشكور',
    'hi',
    'hello',
    'hey',
    'good morning',
    'good evening',
    'please',
    'thanks',
    'thank you',
  ];

  // بادئات استخراج الحقول المهيكلة (مطبّعة باللغة العربية/الإنجليزية)
  static const List<String> _nameLabels = [
    'اسم العميل',
    'اسم العميله',
    'اسم الزبون',
    'اسم الزبونه',
    'صاحب الطلب',
    'الاسم',
    'اسم',
    'العميل',
    'العميله',
    'الزبون',
    'الزبونه',
    'customer name',
    'client name',
    'full name',
    'customer',
    'client',
    'buyer',
    'name',
  ];

  static const List<String> _phoneLabels = [
    'رقم الجوال',
    'رقم الهاتف',
    'رقم الواتساب',
    'رقم الواتس',
    'رقم التواصل',
    'الجوال',
    'جوال',
    'جوالي',
    'الهاتف',
    'هاتف',
    'الرقم',
    'رقمي',
    'تلفون',
    'تليفون',
    'موبايل',
    'واتساب',
    'واتس',
    'phone number',
    'mobile number',
    'whatsapp',
    'phone',
    'mobile',
    'tel',
    'contact',
  ];

  static const List<String> _addressLabels = [
    'الحي او الاستلام',
    'الحي/الاستلام',
    'عنوان التوصيل',
    'التوصيل الي',
    'التوصيل ل',
    'العنوان',
    'عنوان',
    'الحي',
    'حي',
    'المنطقه',
    'الموقع',
    'المكان',
    'التوصيل',
    'الاستلام',
    'delivery address',
    'deliver to',
    'address',
    'location',
    'neighborhood',
    'district',
    'area',
    'delivery',
    'pickup',
  ];

  static const List<String> _orderLabels = [
    'الطلب والكميه',
    'الطلبات والكميه',
    'الطلب والعدد',
    'الاصناف والكميه',
    'الطلبات',
    'الطلب',
    'الاصناف',
    'المنتجات',
    'order items',
    'order details',
    'items',
    'order',
  ];

  static const List<String> _noteLabels = [
    'ملاحظات اضافيه',
    'ملاحظات',
    'ملاحظه',
    'تنبيه',
    'تفاصيل اضافيه',
    'تفاصيل',
    'وقت الاستلام',
    'وقت التوصيل',
    'موعد التسليم',
    'الموعد',
    'الوقت',
    'المناسبه',
    'delivery time',
    'pickup time',
    'instructions',
    'remarks',
    'comments',
    'notes',
    'note',
    'time',
  ];

  // كلمات دالة على الاستلام الشخصي
  static const List<String> _pickupKeywords = [
    'استلام من المحل',
    'استلام من البيت',
    'استلام من عندكم',
    'استلام شخصي',
    'استلام ذاتي',
    'باجي اخذها',
    'باجي اخذه',
    'باجي استلم',
    'بجي اخذها',
    'بجي اخذه',
    'بجي استلم',
    'ساستلم',
    'استلمها بنفسي',
    'استلمه بنفسي',
    'اخذها بنفسي',
    'اخذه بنفسي',
    'استلام',
    'بنفسي',
    'حضوري',
    'self pickup',
    'self-pickup',
    'pick up',
    'pick-up',
    'pickup',
    'takeaway',
    'take away',
    'in-store',
    'collect',
  ];

  // كلمات دالة على التوصيل
  static const List<String> _deliveryKeywords = [
    'توصيل',
    'مندوب',
    'العنوان',
    'عنوان',
    'الحي',
    'توصلها',
    'توصله',
    'للمنزل',
    'للبيت',
    'شحن',
    'delivery',
    'deliver',
    'courier',
    'driver',
    'shipping',
    'address',
    'drop off',
    'dropoff',
  ];

  // كلمات الأعداد العربية الشائعة للكميات
  static const Map<String, int> _arabicQuantityWords = {
    'واحد': 1,
    'واحده': 1,
    'حبه': 1,
    'علبه': 1,
    'صحن': 1,
    'صينيه': 1,
    'كيس': 1,
    'قطعه': 1,
    'اثنين': 2,
    'اثنان': 2,
    'ثنتين': 2,
    'حبتين': 2,
    'علبتين': 2,
    'صحنين': 2,
    'صينيتين': 2,
    'كيسين': 2,
    'قطعتين': 2,
    'كيلوين': 2,
    'ثلاث': 3,
    'ثلاثه': 3,
    'اربع': 4,
    'اربعه': 4,
    'خمس': 5,
    'خمسه': 5,
    'ست': 6,
    'سته': 6,
    'سبع': 7,
    'سبعه': 7,
    'ثمان': 8,
    'ثمانيه': 8,
    'تسع': 9,
    'تسعه': 9,
    'عشر': 10,
    'عشره': 10,
  };

  /// تطبيع النص العربي والإنجليزي للمطابقة الذكية
  /// - تحويل الحروف اللاتينية إلى صغيرة
  /// - إزالة التشكيل والتطويل
  /// - توحيد الهمزات (أ/إ/آ/ٱ -> ا) والتاء المربوطة (ة -> ه) والألف المقصورة (ى -> ي)
  static String normalizeText(String input) {
    if (input.isEmpty) return '';
    final converted = YemenPhoneHelper.convertArabicIndicDigits(input);
    final stripped = converted
        .replaceAll(_bidiMarksRegex, '')
        .replaceAll(_arabicDiacriticsRegex, '')
        .toLowerCase();

    final buffer = StringBuffer();
    for (int i = 0; i < stripped.length; i++) {
      final ch = stripped[i];
      switch (ch) {
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
          buffer.write('ا');
          break;
        case 'ة':
          buffer.write('ه');
          break;
        case 'ى':
          buffer.write('ي');
          break;
        default:
          buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// تحليل رسالة واتساب خام وإرجاع بيانات الطلب والأصناف المطابقة للكتالوج
  static ParsedWhatsAppOrder parse(String rawText, List<Product> catalog) {
    final cleanedInput = YemenPhoneHelper.convertArabicIndicDigits(rawText)
        .replaceAll(_bidiMarksRegex, '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (cleanedInput.isEmpty) {
      return const ParsedWhatsAppOrder();
    }

    String? customerName;
    String? customerPhone;
    String? deliveryAddress;
    String? deliveryType;
    final explicitNotes = <String>[];
    final bodyLinesForItems = <String>[];
    final userContentLinesForDelivery = <String>[];

    final lines = cleanedInput.split('\n');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_isDividerLine(line)) continue;

      final normalizedLine = normalizeText(line);
      if (_isBoilerplateLine(normalizedLine)) continue;

      final structured = _parseStructuredLine(line);
      if (structured != null) {
        final value = _cleanFieldValue(structured.value);
        switch (structured.kind) {
          case _StructuredKind.name:
            if (value != null && customerName == null) {
              // إزالة أي رقم جوال مُدمج بالخطأ في سطر الاسم
              final phoneInName = _extractPhoneFromText(value, allowGeneral: true);
              if (phoneInName != null && customerPhone == null) {
                customerPhone = phoneInName.cleanedPhone;
                final withoutPhone =
                    _removeSpan(value, phoneInName.start, phoneInName.end).trim();
                if (withoutPhone.isNotEmpty) {
                  customerName = _stripTrailingSeparators(withoutPhone);
                }
              } else {
                customerName = value;
              }
            }
            break;

          case _StructuredKind.phone:
            if (value != null && customerPhone == null) {
              final extracted = _extractPhoneFromText(value, allowGeneral: true);
              if (extracted != null) {
                customerPhone = extracted.cleanedPhone;
              }
            }
            break;

          case _StructuredKind.address:
            if (value != null) {
              userContentLinesForDelivery.add(value);
              final isPickupValue = _containsPickupKeyword(normalizeText(value));
              final isDeliveryLabel =
                  structured.normalizedLabel.contains('عنوان') ||
                  structured.normalizedLabel.contains('حي') ||
                  structured.normalizedLabel.contains('توصيل') ||
                  structured.normalizedLabel.contains('address') ||
                  structured.normalizedLabel.contains('delivery') ||
                  structured.normalizedLabel.contains('location') ||
                  structured.normalizedLabel.contains('area');
              final isPurePickupLabel =
                  structured.normalizedLabel == 'الاستلام' ||
                  structured.normalizedLabel == 'pickup';

              if (isPickupValue) {
                deliveryType = AppConstants.deliveryPickup;
                // إذا كتب مثلاً "استلام من المحل" فهذا ليس عنوان توصيل
                final strippedPickup = _stripPickupWords(value);
                if (strippedPickup.isNotEmpty &&
                    _containsDeliveryKeyword(normalizeText(strippedPickup))) {
                  deliveryAddress ??= strippedPickup;
                }
              } else if (isPurePickupLabel) {
                deliveryType = AppConstants.deliveryPickup;
              } else {
                // سحب رقم الجوال إن وُجد في سطر العنوان
                var addrVal = value;
                final phoneInAddr = _extractPhoneFromText(addrVal, allowGeneral: false);
                if (phoneInAddr != null) {
                  customerPhone ??= phoneInAddr.cleanedPhone;
                  addrVal = _removeSpan(addrVal, phoneInAddr.start, phoneInAddr.end).trim();
                }
                final cleanedAddr = _stripTrailingSeparators(addrVal);
                if (cleanedAddr.isNotEmpty) {
                  deliveryAddress ??= cleanedAddr;
                  if (isDeliveryLabel) {
                    deliveryType ??= AppConstants.deliveryDelivery;
                  }
                }
              }
            }
            break;

          case _StructuredKind.order:
            if (value != null) {
              bodyLinesForItems.add(value);
              userContentLinesForDelivery.add(value);
            }
            break;

          case _StructuredKind.note:
            if (value != null) {
              explicitNotes.add(value);
              userContentLinesForDelivery.add(value);
            }
            break;
        }
      } else {
        bodyLinesForItems.add(line);
        userContentLinesForDelivery.add(line);
      }
    }

    // 1) استخراج رقم الجوال من نص الطلب غير المهيكل إذا لم يُستخرج من سطر مخصص
    final sanitizedItemLines = <String>[];
    for (final line in bodyLinesForItems) {
      var working = line;
      final phoneMatch = _extractPhoneWithOptionalLabel(working);
      if (phoneMatch != null) {
        customerPhone ??= phoneMatch.cleanedPhone;
        working = _removeSpan(working, phoneMatch.fullStart, phoneMatch.fullEnd);
      }
      sanitizedItemLines.add(working);
    }

    // محاولة أخيرة لاستخراج الجوال من كامل النص الخام إن لم يُعثر عليه بعد
    if (customerPhone == null) {
      final fallbackPhone = _extractPhoneFromText(cleanedInput, allowGeneral: false);
      if (fallbackPhone != null) {
        customerPhone = fallbackPhone.cleanedPhone;
      }
    }

    // 2) استخراج نوع التسليم والعنوان المضمّن في الرسائل العفوية غير المهيكلة
    final deliveryCorpus = userContentLinesForDelivery.join('\n');
    final sanitizedDeliveryCorpus = sanitizedItemLines.join('\n');

    if (deliveryAddress == null) {
      final inlineAddr = _extractInlineAddress(sanitizedDeliveryCorpus);
      if (inlineAddr != null) {
        deliveryAddress = inlineAddr.address;
        deliveryType ??= AppConstants.deliveryDelivery;
      }
    }

    if (deliveryType == null) {
      final normCorpus = normalizeText(deliveryCorpus);
      if (_containsPickupKeyword(normCorpus)) {
        deliveryType = AppConstants.deliveryPickup;
      } else if (_containsDeliveryKeyword(normCorpus) || deliveryAddress != null) {
        deliveryType = AppConstants.deliveryDelivery;
      }
    }

    // 3) مطابقة منتجات الكتالوج واستخراج الكميات
    final matchedItems = _matchCatalogItems(sanitizedItemLines, catalog);

    // 4) تجميع الملاحظات النهائية
    String? rawNotes;
    if (explicitNotes.isNotEmpty) {
      rawNotes = explicitNotes.join(' | ');
    } else if (matchedItems.isEmpty &&
        customerName == null &&
        customerPhone == null &&
        deliveryAddress == null &&
        deliveryType == null) {
      // نص حر غير معروف — نحفظه كملاحظات فقط إذا لم يكن مجرد تحية فارغة
      final normWhole = normalizeText(cleanedInput)
          .replaceAll(RegExp(r'[^\u0621-\u064Aa-z0-9\s]'), '')
          .trim();
      if (normWhole.isNotEmpty && !_isGreetingOnly(normWhole)) {
        rawNotes = cleanedInput;
      }
    }

    return ParsedWhatsAppOrder(
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      deliveryType: deliveryType,
      matchedItems: matchedItems,
      rawNotes: rawNotes,
    );
  }

  /// تقسيم السطر المهيكل (`المفتاح: القيمة`) وتحديد نوعه
  static _StructuredLine? _parseStructuredLine(String line) {
    // إزالة الرموز البادئة مثل - أو • أو *
    final cleanedLine = line.replaceFirst(RegExp(r'^[\s\-•*▪▫►▻●○✓✔✅🔹🔸📌📍👤📞📱📝]+'), '');

    final colonIndex = _findHeaderSeparatorIndex(cleanedLine);
    if (colonIndex <= 0) return null;

    final rawLabel = cleanedLine.substring(0, colonIndex).trim();
    final rawValue = cleanedLine.substring(colonIndex + 1).trim();
    final normLabel = normalizeText(rawLabel)
        .replaceAll(RegExp(r'[\*_\[\]\(\)]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normLabel.isEmpty || normLabel.length > 30) return null;

    if (_matchesLabel(normLabel, _nameLabels)) {
      return _StructuredLine(_StructuredKind.name, normLabel, rawValue);
    }
    if (_matchesLabel(normLabel, _phoneLabels)) {
      return _StructuredLine(_StructuredKind.phone, normLabel, rawValue);
    }
    if (_matchesLabel(normLabel, _orderLabels)) {
      return _StructuredLine(_StructuredKind.order, normLabel, rawValue);
    }
    if (_matchesLabel(normLabel, _addressLabels)) {
      return _StructuredLine(_StructuredKind.address, normLabel, rawValue);
    }
    if (_matchesLabel(normLabel, _noteLabels)) {
      return _StructuredLine(_StructuredKind.note, normLabel, rawValue);
    }
    return null;
  }

  static int _findHeaderSeparatorIndex(String line) {
    final asciiColon = line.indexOf(':');
    final fullWidthColon = line.indexOf('：');
    if (asciiColon == -1) return fullWidthColon;
    if (fullWidthColon == -1) return asciiColon;
    return asciiColon < fullWidthColon ? asciiColon : fullWidthColon;
  }

  static bool _matchesLabel(String normLabel, List<String> candidates) {
    for (final candidate in candidates) {
      if (normLabel == candidate) return true;
    }
    return false;
  }

  static String? _cleanFieldValue(String raw) {
    final trimmed = raw
        .replaceAll(RegExp(r'^[\s\-:：/\\_.…]+'), '')
        .replaceAll(RegExp(r'[\s/\\_.…]+$'), '')
        .trim();
    if (trimmed.isEmpty) return null;
    // رفض القيم النائبة الفارغة مثل "..." أو "___"
    if (RegExp(r'^[\.\-_/\s]+$').hasMatch(trimmed)) return null;
    return trimmed;
  }

  static bool _isDividerLine(String line) {
    return RegExp(r'^[\-=~_*•·\s]{3,}$').hasMatch(line);
  }

  static bool _isBoilerplateLine(String normalizedLine) {
    for (final phrase in _ignoredBoilerplatePhrases) {
      if (normalizedLine.contains(phrase)) return true;
    }
    return false;
  }

  static bool _isGreetingOnly(String normalizedText) {
    final collapsed = normalizedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return true;
    return _greetingOnlyPhrases.contains(collapsed);
  }

  /// استخراج رقم الجوال مع الكلمة السابقة له إن وُجدت (مثل "جوالي 771234567")
  static _PhoneExtraction? _extractPhoneWithOptionalLabel(String text) {
    // محاولة استخراج مع كلمة دالة مسبقة
    final labeledRegex = RegExp(
      r'(?:رقم\s+الجوال|رقم\s+الهاتف|الجوال|جوالي|جوال|الهاتف|هاتف|الرقم|رقمي|تلفون|تليفون|موبايل|واتساب|واتس|phone|mobile|tel|whatsapp|contact)\s*[:：\-]?\s*(\+?\d[\d\s\-().]{6,18}\d)',
      caseSensitive: false,
    );
    final labeledMatch = labeledRegex.firstMatch(text);
    if (labeledMatch != null) {
      final candidate = labeledMatch.group(1)!;
      if (!_looksLikeDate(candidate) && YemenPhoneHelper.isValid(candidate)) {
        return _PhoneExtraction(
          cleanedPhone: YemenPhoneHelper.cleanPhoneNumber(candidate),
          start: labeledMatch.start,
          end: labeledMatch.end,
          fullStart: labeledMatch.start,
          fullEnd: labeledMatch.end,
        );
      }
    }

    final plain = _extractPhoneFromText(text, allowGeneral: false);
    if (plain != null) {
      return _PhoneExtraction(
        cleanedPhone: plain.cleanedPhone,
        start: plain.start,
        end: plain.end,
        fullStart: plain.start,
        fullEnd: plain.end,
      );
    }
    return null;
  }

  /// استخراج رقم هاتف صالح من نص (يدعم اليمني، السعودي، الخليجي، والدولي)
  static _PhoneExtraction? _extractPhoneFromText(
    String text, {
    required bool allowGeneral,
  }) {
    final patterns = <RegExp>[
      // 1. صيغة دولية صريحة تبدأ بـ + أو 00
      RegExp(r'(?<!\d)(?:\+|00)(?:967|966|971|965|974|968|973|[1-9]\d{0,2})(?:[\s\-().]*\d){7,12}(?!\d)'),
      // 2. صيغة دولية يمنية أو خليجية بدون + أو 00
      RegExp(r'(?<!\d)(?:9677[01378]|9665|9715|965[569]|974[3567]|968[79]|9733)(?:[\s\-]?\d){7,8}(?!\d)'),
      // 3. جوال يمني محلي (77/78/71/73/70) بطول 9 أو مع 0 بطول 10
      RegExp(r'(?<!\d)0?7[01378](?:[\s\-]?\d){7}(?!\d)'),
      // 4. جوال سعودي محلي (05xxxxxxxx)
      RegExp(r'(?<!\d)05(?:[\s\-]?\d){8}(?!\d)'),
      if (allowGeneral)
        // 5. أرقام عامة صالحة فقط داخل سطر مُعنون بـ "الجوال:" أو "Phone:"
        RegExp(r'(?<!\d)\+?\d(?:[\s\-().]?\d){6,14}(?!\d)'),
    ];

    for (final regex in patterns) {
      for (final match in regex.allMatches(text)) {
        final raw = match.group(0)!;
        if (_looksLikeDate(raw)) continue;
        final cleaned = YemenPhoneHelper.cleanPhoneNumber(raw);
        if (cleaned.isNotEmpty && YemenPhoneHelper.isValid(cleaned)) {
          return _PhoneExtraction(
            cleanedPhone: cleaned,
            start: match.start,
            end: match.end,
            fullStart: match.start,
            fullEnd: match.end,
          );
        }
      }
    }
    return null;
  }

  static bool _looksLikeDate(String value) {
    final trimmed = value.trim();
    return RegExp(r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$').hasMatch(trimmed) ||
        RegExp(r'^\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}$').hasMatch(trimmed);
  }

  static String _removeSpan(String text, int start, int end) {
    final before = text.substring(0, start);
    final after = text.substring(end);
    return '$before $after'.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  static String _stripTrailingSeparators(String input) {
    return input.replaceAll(RegExp(r'^[\s\-،,.:：]+|[\s\-،,.:：]+$'), '').trim();
  }

  /// استخراج العنوان المضمّن داخل جملة عفوية (مثل: "توصيل حي حدة" أو "Deliver to Olaya St")
  static _InlineAddress? _extractInlineAddress(String text) {
    // 1. عبارة تبدأ بـ توصيل متبوعة بعنوان
    final arDeliveryRegex = RegExp(
      r'(?:التوصيل|توصيل)(?:\s+(?:إلى|الى|لـ|ل|في|عند))?\s+([^\n،,.;؛]+)',
    );
    final arMatch = arDeliveryRegex.firstMatch(text);
    if (arMatch != null) {
      final candidate = _cleanInlineAddress(arMatch.group(1)!);
      if (candidate != null) {
        return _InlineAddress(candidate);
      }
    }

    // 2. ذكر صريح لحي أو شارع أو جولة أو منطقة في النص العفوي
    final arAreaRegex = RegExp(
      r'((?:حي|شارع|جولة|جوله|حارة|حاره|منطقة|منطقه)\s+[^\n،,.;؛]+)',
    );
    final arAreaMatch = arAreaRegex.firstMatch(text);
    if (arAreaMatch != null) {
      final candidate = _cleanInlineAddress(arAreaMatch.group(1)!);
      if (candidate != null) {
        return _InlineAddress(candidate);
      }
    }

    // 3. صيغة إنجليزية: "deliver to ..." / "delivery to ..." / "address ..."
    final enDeliveryRegex = RegExp(
      r'(?:deliver(?:y)?\s+to|ship\s+to|address\s+is)\s+([^\n,.;]+)',
      caseSensitive: false,
    );
    final enMatch = enDeliveryRegex.firstMatch(text);
    if (enMatch != null) {
      final candidate = _cleanInlineAddress(enMatch.group(1)!);
      if (candidate != null) {
        return _InlineAddress(candidate);
      }
    }

    return null;
  }

  static String? _cleanInlineAddress(String raw) {
    // إزالة أي بقايا كلمات استلام أو تذييل غير عنواني
    var cleaned = raw
        .replaceAll(RegExp(r'\s+(?:لو سمحت|لو سمحتي|من فضلك|وشكرا|وشكراً|شكرا|شكراً|please|thanks).*$', caseSensitive: false), '')
        .trim();
    cleaned = _stripTrailingSeparators(cleaned);
    if (cleaned.length < 2) return null;
    final norm = normalizeText(cleaned);
    if (_containsPickupKeyword(norm)) return null;
    // رفض الكلمات المنفردة العامة مثل "اليوم" أو "بكرة" أو "فوري"
    const nonAddressWords = {
      'اليوم',
      'بكره',
      'غدا',
      'الان',
      'فوري',
      'سريع',
      'مجاني',
      'today',
      'tomorrow',
      'now',
      'asap',
    };
    if (nonAddressWords.contains(norm)) return null;
    return cleaned;
  }

  static bool _containsPickupKeyword(String normalizedText) {
    for (final kw in _pickupKeywords) {
      if (_containsWholePhrase(normalizedText, kw)) return true;
    }
    return false;
  }

  static bool _containsDeliveryKeyword(String normalizedText) {
    for (final kw in _deliveryKeywords) {
      if (_containsWholePhrase(normalizedText, kw)) return true;
    }
    return false;
  }

  static String _stripPickupWords(String text) {
    var result = text;
    for (final kw in ['استلام من المحل', 'استلام شخصي', 'استلام', 'pickup', 'pick up']) {
      result = result.replaceAll(RegExp(RegExp.escape(kw), caseSensitive: false), '');
    }
    return _stripTrailingSeparators(result);
  }

  static bool _containsWholePhrase(String haystack, String needle) {
    var index = haystack.indexOf(needle);
    while (index != -1) {
      final end = index + needle.length;
      final validStart = index == 0 || !_isLetter(haystack[index - 1]);
      final validEnd = end == haystack.length || !_isLetter(haystack[end]);
      if (validStart && validEnd) return true;
      index = haystack.indexOf(needle, index + 1);
    }
    return false;
  }

  /// مطابقة أصناف الكتالوج (الأطول اسماً أولاً) واستخراج الكمية المجاورة لكل صنف
  static List<ParsedOrderLine> _matchCatalogItems(
    List<String> lines,
    List<Product> catalog,
  ) {
    if (catalog.isEmpty || lines.isEmpty) return const [];

    // تجهيز الكتالوج: تصفية الأسماء الفارغة والترتيب تنازلياً حسب الطول (والنشطة أولاً عند التساوي)
    final preparedCatalog = <_PreparedProduct>[];
    for (final product in catalog) {
      final normName = _collapseSpaces(normalizeText(product.name));
      if (normName.isEmpty) continue;
      preparedCatalog.add(_PreparedProduct(product: product, normalizedName: normName));
    }
    if (preparedCatalog.isEmpty) return const [];

    preparedCatalog.sort((a, b) {
      final lenCmp = b.normalizedName.length.compareTo(a.normalizedName.length);
      if (lenCmp != 0) return lenCmp;
      if (a.product.isActive != b.product.isActive) {
        return a.product.isActive ? -1 : 1;
      }
      return 0;
    });

    final aggregated = <String, ParsedOrderLine>{};
    final orderOfAppearance = <String>[];

    for (final rawLine in lines) {
      if (rawLine.trim().isEmpty) continue;
      // إزالة ترقيم القوائم في بداية السطر مثل "1. " أو "2) " حتى لا يُحسب ككمية
      final withoutListIndex =
          rawLine.replaceFirst(RegExp(r'^\s*\d+\s*[\.\)]\s+'), '');
      // إزالة رموز تنسيق واتساب مثل * و _ و ~
      final cleanLine = withoutListIndex.replaceAll(RegExp(r'[*_~]'), ' ');
      final normLine = _collapseSpaces(normalizeText(cleanLine));
      if (normLine.isEmpty) continue;

      final consumed = List<bool>.filled(normLine.length, false);
      final lineMatches = <_ProductSpan>[];

      for (final entry in preparedCatalog) {
        final needle = entry.normalizedName;
        var searchFrom = 0;
        while (searchFrom < normLine.length) {
          final idx = normLine.indexOf(needle, searchFrom);
          if (idx == -1) break;
          final end = idx + needle.length;
          searchFrom = idx + 1;

          if (_isSpanConsumed(consumed, idx, end)) continue;

          final boundaryStart = _resolveMatchStartWithOptionalPrefix(
            normLine,
            idx,
            needle,
          );
          if (boundaryStart == null) continue;
          if (end < normLine.length && _isLetter(normLine[end])) continue;

          for (int k = boundaryStart; k < end; k++) {
            consumed[k] = true;
          }
          lineMatches.add(
            _ProductSpan(
              product: entry.product,
              start: boundaryStart,
              end: end,
            ),
          );
          searchFrom = end;
        }
      }

      if (lineMatches.isEmpty) continue;

      // ترتيب المطابقات حسب موضع الظهور في السطر
      lineMatches.sort((a, b) => a.start.compareTo(b.start));

      // تتبع الحدود المستهلكة لمنع تداخل الكمية بين منتجين متجاورين
      var previousRightConsumedEnd = 0;

      for (int i = 0; i < lineMatches.length; i++) {
        final current = lineMatches[i];
        final prevEnd = i == 0 ? 0 : lineMatches[i - 1].end;
        final leftBound =
            prevEnd > previousRightConsumedEnd ? prevEnd : previousRightConsumedEnd;
        final nextStart = i + 1 < lineMatches.length
            ? lineMatches[i + 1].start
            : normLine.length;

        final leftSegment = normLine.substring(leftBound, current.start);
        final rightSegment = normLine.substring(current.end, nextStart);

        final leftQty = _extractQuantityBefore(leftSegment);
        final rightQty = _extractQuantityAfter(
          rightSegment,
          hasNextProduct: i + 1 < lineMatches.length,
        );

        int resolvedQty = 1;
        if (rightQty != null && rightQty.isExplicit) {
          // الصيغة الصريحة بعد الاسم مثل "معمول × 3" أو "معمول عدد 4" لها الأولوية القصوى
          resolvedQty = rightQty.quantity;
          previousRightConsumedEnd = current.end + rightQty.consumedLength;
        } else if (leftQty != null) {
          resolvedQty = leftQty.quantity;
        } else if (rightQty != null) {
          resolvedQty = rightQty.quantity;
          previousRightConsumedEnd = current.end + rightQty.consumedLength;
        }

        final id = current.product.id;
        if (aggregated.containsKey(id)) {
          final existing = aggregated[id]!;
          aggregated[id] = ParsedOrderLine(
            product: existing.product,
            quantity: existing.quantity + resolvedQty,
          );
        } else {
          orderOfAppearance.add(id);
          aggregated[id] = ParsedOrderLine(
            product: current.product,
            quantity: resolvedQty,
          );
        }
      }
    }

    return [
      for (final id in orderOfAppearance) aggregated[id]!,
    ];
  }

  /// التحقق من حدود بداية الكلمة مع دعم البادئات العربية الشائعة ("ال" و "و" و "وال")
  static int? _resolveMatchStartWithOptionalPrefix(
    String text,
    int matchIndex,
    String normalizedProductName,
  ) {
    if (matchIndex == 0 || !_isLetter(text[matchIndex - 1])) {
      return matchIndex;
    }

    // السماح ببادئة "و" العاطفة مثل "وبخور" إذا كانت مسبوقة بفاصل
    if (normalizedProductName.length >= 3 && text[matchIndex - 1] == 'و') {
      final beforeWaw = matchIndex - 1;
      if (beforeWaw == 0 || !_isLetter(text[beforeWaw - 1])) {
        return beforeWaw;
      }
    }

    // السماح بأداة التعريف "ال" أو "وال" إذا لم يبدأ اسم المنتج بـ "ال"
    if (normalizedProductName.length >= 3 &&
        !normalizedProductName.startsWith('ال') &&
        matchIndex >= 2 &&
        text.substring(matchIndex - 2, matchIndex) == 'ال') {
      final alStart = matchIndex - 2;
      if (alStart == 0 || !_isLetter(text[alStart - 1])) {
        return alStart;
      }
      if (alStart >= 1 && text[alStart - 1] == 'و') {
        final walStart = alStart - 1;
        if (walStart == 0 || !_isLetter(text[walStart - 1])) {
          return walStart;
        }
      }
    }

    return null;
  }

  static bool _isSpanConsumed(List<bool> consumed, int start, int end) {
    for (int i = start; i < end; i++) {
      if (consumed[i]) return true;
    }
    return false;
  }

  /// استخراج الكمية قبل اسم الصنف (مثل: "3 معمول" / "2x cake" / "عدد 4 معمول" / "حبتين معمول")
  static _QuantityMatch? _extractQuantityBefore(String leftSegment) {
    // نأخذ المقطع بعد آخر فاصل جملة (فاصلة، سطر، +)
    final clauseMatch = RegExp(r'([^،,+;؛\n]*)$').firstMatch(leftSegment);
    final clause = (clauseMatch?.group(1) ?? leftSegment).trim();
    if (clause.isEmpty) return null;

    // 1. صيغة صريحة مع "عدد" / "الكمية" / "qty" أو علامة ضرب قبل الاسم
    final explicitBefore = RegExp(
      r'(?:(?:عدد|العدد|كميه|الكميه|qty|quantity)\s*[:：\-]?\s*(\d{1,3})|(\d{1,3})\s*[×xX*])\s*(?:حبه|حبات|علبه|علب|صحن|صحون|صينيه|صواني|قطعه|قطع|كيلو|كيس|اكياس|عبوه|عبوات|pcs|pc|box|boxes|packs|pack)?$',
    ).firstMatch(clause);
    if (explicitBefore != null) {
      final numStr = explicitBefore.group(1) ?? explicitBefore.group(2);
      final qty = int.tryParse(numStr ?? '');
      if (qty != null && qty >= 1 && qty <= 500) {
        return _QuantityMatch(quantity: qty, isExplicit: true, consumedLength: 0);
      }
    }

    // 2. رقم مباشر قبل الاسم (مع وحدة اختيارية أو واو عاطفة مثل "و2")
    final bareBefore = RegExp(
      r'(?:^|[\sو\-(\[:：])(\d{1,3})\s*(?:حبه|حبات|علبه|علب|صحن|صحون|صينيه|صواني|قطعه|قطع|كيلو|كيس|اكياس|عبوه|عبوات|pcs|pc|box|boxes|packs|pack)?$',
    ).firstMatch(clause);
    if (bareBefore != null) {
      final qty = int.tryParse(bareBefore.group(1)!);
      if (qty != null && qty >= 1 && qty <= 500) {
        return _QuantityMatch(quantity: qty, isExplicit: false, consumedLength: 0);
      }
    }

    // 3. كلمة عددية عربية قبل الاسم (مثل: "حبتين معمول" أو "ثلاث علب معمول")
    final tokens = clause
        .split(RegExp(r'[\s\-(\[:：]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isNotEmpty) {
      for (int offset = 1; offset <= 2 && offset <= tokens.length; offset++) {
        var token = tokens[tokens.length - offset];
        if (token.startsWith('و') && token.length > 2) {
          final withoutWaw = token.substring(1);
          if (_arabicQuantityWords.containsKey(withoutWaw)) {
            token = withoutWaw;
          }
        }
        final wordQty = _arabicQuantityWords[token];
        if (wordQty != null) {
          return _QuantityMatch(
            quantity: wordQty,
            isExplicit: false,
            consumedLength: 0,
          );
        }
      }
    }

    return null;
  }

  /// استخراج الكمية بعد اسم الصنف (مثل: "معمول × 3" / "معمول عدد 4" / "معمول (2)")
  static _QuantityMatch? _extractQuantityAfter(
    String rightSegment, {
    required bool hasNextProduct,
  }) {
    if (rightSegment.trim().isEmpty) return null;

    // 1. صيغة صريحة بعد الاسم: × 3 / x 3 / عدد 4 / qty 4 / (3)
    final explicitAfter = RegExp(
      r'^\s*(?:[×xX*]\s*(\d{1,3})|(?:عدد|العدد|كميه|الكميه|qty|quantity)\s*[:：\-]?\s*(\d{1,3})|[:：\-]\s*(\d{1,3})(?!\s*(?:ر\.?ي|ريال|سعودي|دولار|yer|sar|usd|\$|\u20C1))|\(\s*(\d{1,3})\s*\))',
    ).firstMatch(rightSegment);
    if (explicitAfter != null) {
      final numStr = explicitAfter.group(1) ??
          explicitAfter.group(2) ??
          explicitAfter.group(3) ??
          explicitAfter.group(4);
      final qty = int.tryParse(numStr ?? '');
      if (qty != null && qty >= 1 && qty <= 500 && !_isFollowedByCurrency(rightSegment, explicitAfter.end)) {
        return _QuantityMatch(
          quantity: qty,
          isExplicit: true,
          consumedLength: explicitAfter.end,
        );
      }
    }

    // 2. رقم مع وحدة بعد الاسم مباشرة (مثل: "معمول 3 حبات" أو "cake 2 boxes")
    final unitAfter = RegExp(
      r'^\s*(\d{1,3})\s*(?:حبه|حبات|علبه|علب|صحن|صحون|صينيه|صواني|قطعه|قطع|كيلو|كيس|اكياس|عبوه|عبوات|pcs|pc|box|boxes|packs|pack)\b',
    ).firstMatch(rightSegment);
    if (unitAfter != null) {
      final qty = int.tryParse(unitAfter.group(1)!);
      if (qty != null && qty >= 1 && qty <= 500) {
        return _QuantityMatch(
          quantity: qty,
          isExplicit: true,
          consumedLength: unitAfter.end,
        );
      }
    }

    // 3. كلمة عددية عربية بعد الاسم مباشرة (مثل: "معمول حبتين")
    final wordAfterMatch = RegExp(r'^\s*([\u0621-\u064A]+)').firstMatch(rightSegment);
    if (wordAfterMatch != null) {
      final word = wordAfterMatch.group(1)!;
      final wordQty = _arabicQuantityWords[word];
      if (wordQty != null) {
        return _QuantityMatch(
          quantity: wordQty,
          isExplicit: false,
          consumedLength: wordAfterMatch.end,
        );
      }
    }

    // 4. رقم مجرد بعد الاسم مباشرة بدون فاصل (مثل: "معمول 3، بخور 2" أو "معمول 3" في نهاية السطر)
    final bareAfter = RegExp(r'^\s*(\d{1,3})(?=$|[\s،,+;؛\n])').firstMatch(rightSegment);
    if (bareAfter != null) {
      final trailing = rightSegment.substring(bareAfter.end);
      // تجنب التقاط الأسعار مثل "4000 ر.ي" أو "4,000"
      if (_isFollowedByCurrency(rightSegment, bareAfter.end) ||
          trailing.startsWith(',')) {
        return null;
      }
      // إذا كان هناك منتج تالٍ ولا يوجد فاصل بعد الرقم (مثل "معمول 2 بخور")،
      // فالأرجح أن "2" تنتمي إلى "بخور" ما لم يكن هناك فاصل بعد "2"
      final hasSeparatorAfterNumber =
          RegExp(r'^\s*(?:[،,+;؛]|و(?:\s|$)|and\b)').hasMatch(trailing);
      if (!hasNextProduct || hasSeparatorAfterNumber) {
        final qty = int.tryParse(bareAfter.group(1)!);
        if (qty != null && qty >= 1 && qty <= 500) {
          return _QuantityMatch(
            quantity: qty,
            isExplicit: false,
            consumedLength: bareAfter.end,
          );
        }
      }
    }

    return null;
  }

  static bool _isFollowedByCurrency(String text, int offset) {
    final rest = text.substring(offset);
    return RegExp(
      r'^\s*(?:ر\.?\s*ي|ر\.?\s*س|ريال|سعودي|يمني|دولار|yer|sar|usd|\$|\u20C1)',
      caseSensitive: false,
    ).hasMatch(rest);
  }

  static bool _isLetter(String ch) => _letterRegex.hasMatch(ch);

  static String _collapseSpaces(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

enum _StructuredKind { name, phone, address, order, note }

class _StructuredLine {
  final _StructuredKind kind;
  final String normalizedLabel;
  final String value;

  const _StructuredLine(this.kind, this.normalizedLabel, this.value);
}

class _PhoneExtraction {
  final String cleanedPhone;
  final int start;
  final int end;
  final int fullStart;
  final int fullEnd;

  const _PhoneExtraction({
    required this.cleanedPhone,
    required this.start,
    required this.end,
    required this.fullStart,
    required this.fullEnd,
  });
}

class _InlineAddress {
  final String address;
  const _InlineAddress(this.address);
}

class _PreparedProduct {
  final Product product;
  final String normalizedName;

  const _PreparedProduct({
    required this.product,
    required this.normalizedName,
  });
}

class _ProductSpan {
  final Product product;
  final int start;
  final int end;

  const _ProductSpan({
    required this.product,
    required this.start,
    required this.end,
  });
}

class _QuantityMatch {
  final int quantity;
  final bool isExplicit;
  final int consumedLength;

  const _QuantityMatch({
    required this.quantity,
    required this.isExplicit,
    required this.consumedLength,
  });
}
