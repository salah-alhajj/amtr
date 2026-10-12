import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ويدجت الأيقونة الرسمية لتطبيق واتساب بصيغة SVG فيكتور فائقة الدقة
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const WhatsAppIcon({
    super.key,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/whatsapp.svg',
      width: size,
      height: size,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      semanticsLabel: 'WhatsApp',
    );
  }
}
