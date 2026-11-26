import 'package:flutter/material.dart';
import '../constants.dart';
import '../theme/app_colors.dart';
import 'saudi_riyal_icon.dart';

/// ويدجت نص ذكي يستبدل أي ظهور لرمز الريال السعودي (U+20C1 / ⃁) برمز فيكتور SVG الرسمي (SAMA)
/// لمنع ظهور الرمز كعلامة استفهام أو مربع مفقود عبر جميع الأنظمة وإصدارات الخطوط.
class SaudiRiyalText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const SaudiRiyalText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    if (!data.contains(AppConstants.sarSymbol)) {
      return Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }

    final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
    final fontSize = resolvedStyle.fontSize ?? 14.0;
    final iconSize = fontSize * 0.95;
    final resolvedColor = resolvedStyle.color ?? AppColors.textPrimary;

    final parts = data.split(AppConstants.sarSymbol);
    final spans = <InlineSpan>[];

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }
      if (i < parts.length - 1) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: SaudiRiyalIcon(
                width: iconSize,
                height: iconSize * 0.92,
                color: resolvedColor,
              ),
            ),
          ),
        );
      }
    }

    return Text.rich(
      TextSpan(style: resolvedStyle, children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: softWrap ?? true,
    );
  }
}
