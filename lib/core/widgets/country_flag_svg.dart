import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ويدجت احترافي لعرض أعلام الدول بصيغة SVG فائقة النقاء والدقة
/// بديل موحد وخالٍ تماماً من الإيموجيز المشوهة أو غير المتسقة
class CountryFlagSvg extends StatelessWidget {
  final String flagCode; // 'ye', 'sa', 'us', 'gb', 'tr', 'fr', 'es'
  final double width;
  final double height;
  final double borderRadius;
  final bool showBorder;

  const CountryFlagSvg({
    super.key,
    required this.flagCode,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  });

  /// علم الجمهورية اليمنية بصيغة SVG (العلم الحصري والمعتمد للغة العربية)
  const CountryFlagSvg.ye({
    super.key,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  }) : flagCode = 'ye';

  /// علم المملكة العربية السعودية بصيغة SVG
  const CountryFlagSvg.sa({
    super.key,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  }) : flagCode = 'sa';

  /// علم الولايات المتحدة الأمريكية بصيغة SVG (للغة الإنجليزية)
  const CountryFlagSvg.us({
    super.key,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  }) : flagCode = 'us';

  /// علم بريطانيا (المملكة المتحدة) بصيغة SVG
  const CountryFlagSvg.gb({
    super.key,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  }) : flagCode = 'gb';

  /// علم الجمهورية التركية بصيغة SVG (للغة التركية)
  const CountryFlagSvg.tr({
    super.key,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  }) : flagCode = 'tr';

  /// علم الجمهورية الفرنسية بصيغة SVG (للغة الفرنسية)
  const CountryFlagSvg.fr({
    super.key,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  }) : flagCode = 'fr';

  /// علم مملكة إسبانيا بصيغة SVG (للغة الإسبانية)
  const CountryFlagSvg.es({
    super.key,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
    this.showBorder = true,
  }) : flagCode = 'es';

  /// منشئ مخصص لعرض علم الدولة المناسب حسب رمز اللغة
  factory CountryFlagSvg.fromLanguageCode(
    String langCode, {
    Key? key,
    double width = 24,
    double height = 18,
    double borderRadius = 4,
    bool showBorder = true,
  }) {
    final code = switch (langCode.toLowerCase()) {
      'ar' => 'ye', // العلم اليمني فقط للغة العربية
      'en' => 'us',
      'tr' => 'tr',
      'fr' => 'fr',
      'es' => 'es',
      _ => 'ye',
    };
    return CountryFlagSvg(
      key: key,
      flagCode: code,
      width: width,
      height: height,
      borderRadius: borderRadius,
      showBorder: showBorder,
    );
  }

  String _getAssetPath() {
    switch (flagCode.toLowerCase()) {
      case 'sa':
        return 'assets/icons/flags/flag_sa.svg';
      case 'us':
        return 'assets/icons/flags/flag_us.svg';
      case 'gb':
        return 'assets/icons/flags/flag_gb.svg';
      case 'tr':
        return 'assets/icons/flags/flag_tr.svg';
      case 'fr':
        return 'assets/icons/flags/flag_fr.svg';
      case 'es':
        return 'assets/icons/flags/flag_es.svg';
      case 'ye':
      default:
        return 'assets/icons/flags/flag_ye.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: Colors.black.withValues(alpha: 0.12),
                width: 0.8,
              )
            : null,
        boxShadow: showBorder
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - (showBorder ? 0.8 : 0)),
        child: SvgPicture.asset(
          _getAssetPath(),
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// زوج أعلام متكامل للدول العربية (اليمن والسعودية)
class DualArabFlagSvg extends StatelessWidget {
  final double size;

  const DualArabFlagSvg({
    super.key,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.55,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: CountryFlagSvg.sa(
              width: size * 1.05,
              height: size * 0.78,
              borderRadius: 3.5,
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: CountryFlagSvg.ye(
              width: size * 1.05,
              height: size * 0.78,
              borderRadius: 3.5,
            ),
          ),
        ],
      ),
    );
  }
}
