import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

/// ويدجت الرمز الرسمي المعتمد للريال السعودي (SAMA)
/// يعتمد على الفيكتور الرسمي SVG الصادر من البنك المركزي السعودي (viewBox: 0 0 1124.14 1256.39)
class SaudiRiyalIcon extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const SaudiRiyalIcon({
    super.key,
    this.width = 16,
    this.height = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? AppColors.textPrimary;

    return SvgPicture.asset(
      'assets/icons/saudi_riyal_symbol_sama.svg',
      width: width,
      height: height,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      semanticsLabel: 'رمز الريال السعودي',
    );
  }
}
