/// تعريف اللهجات والمسميات البلدية العربية المدعومة مع ملفات ترجمة كاملة (١٠٠٪ من مفاتيح i18n/ar.json) لكل منطقة
class ArabicDialect {
  final String id;
  final String nativeName;
  final String regionSubtitle;
  final String sampleTerms;
  final String? assetPath;

  const ArabicDialect({
    required this.id,
    required this.nativeName,
    required this.regionSubtitle,
    required this.sampleTerms,
    this.assetPath,
  });

  static const String standardId = 'standard';
  static const String yeSanaaId = 'ye_sanaa';
  static const String yeAdenId = 'ye_aden';
  static const String yeTaizId = 'ye_taiz';
  static const String yeHadramautId = 'ye_hadramaut';

  static const ArabicDialect standard = ArabicDialect(
    id: standardId,
    nativeName: 'العربية الفصحى المعاصرة',
    regionSubtitle: 'مصطلحات عربية واضحة وموحدة لجميع البلدان',
    sampleTerms: 'الصندوق • المبيعات • المصروفات',
    assetPath: null,
  );

  static const List<ArabicDialect> supported = [
    standard,
    ArabicDialect(
      id: yeSanaaId,
      nativeName: 'اليمنية — صنعاء والشمال',
      regionSubtitle: 'مسميات سوق صنعاء والمحافظات الشمالية',
      sampleTerms: 'الزلط • الشغل • تقفيل اليوم',
      assetPath: 'i18n/ar_ye_sanaa.json',
    ),
    ArabicDialect(
      id: yeAdenId,
      nativeName: 'اليمنية — عدن والجنوب',
      regionSubtitle: 'مسميات عدن ولحج وأبين والمحافظات الجنوبية',
      sampleTerms: 'البيس • المحل • صاحب التوصيل',
      assetPath: 'i18n/ar_ye_aden.json',
    ),
    ArabicDialect(
      id: yeTaizId,
      nativeName: 'اليمنية — تعز والوسط',
      regionSubtitle: 'مسميات تعز وإب والمناطق الوسطى',
      sampleTerms: 'القروش • الفلوس • دفتر الزبائن',
      assetPath: 'i18n/ar_ye_taiz.json',
      ),
    ArabicDialect(
      id: yeHadramautId,
      nativeName: 'اليمنية — حضرموت والشرق',
      regionSubtitle: 'مسميات حضرموت والمهرة وشبوة',
      sampleTerms: 'الدراهم • الدار • المطالبات',
      assetPath: 'i18n/ar_ye_hadramaut.json',
    ),
  ];

  static ArabicDialect fromId(String? id) {
    if (id == null || id.isEmpty) return standard;
    for (final dialect in supported) {
      if (dialect.id == id) return dialect;
    }
    return standard;
  }
}
