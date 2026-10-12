import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../apple_widgets.dart';

import 'package:flutter/services.dart';

/// حقل إدخال موحد بتصميم آبل (Apple Style Text Field) مع دعم الأيقونات ومسح النص والتحقق الفوري
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final Widget? labelWidget;
  final Widget? suffix;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool showClearButton;
  final Color? backgroundColor;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  const AppTextField({
    super.key,
    this.controller,
    this.label = '',
    this.labelWidget,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.prefixWidget,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onTap,
    this.showClearButton = false,
    this.backgroundColor,
    this.inputFormatters,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? AppColors.darkSurfaceMuted
        : AppColors.surfaceWhite;
    final defaultTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final defaultLabelColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final defaultHintColor = isDark
        ? AppColors.darkTextTertiary
        : AppColors.textTertiary;
    final defaultBorderColor = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;
    final defaultBlue = isDark
        ? AppColors.darkPrimaryBlue
        : AppColors.primaryBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelWidget != null)
          labelWidget!
        else if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: defaultLabelColor,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
        if (labelWidget != null || label.isNotEmpty) const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          validator: validator,
          onChanged: onChanged,
          onTap: onTap,
          inputFormatters: inputFormatters,
          autovalidateMode: autovalidateMode,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: defaultTextColor,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperStyle: TextStyle(fontSize: 11, color: defaultHintColor),
            errorStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.statusDanger,
            ),
            errorMaxLines: 2,
            hintStyle: TextStyle(
              fontSize: 13,
              color: defaultHintColor,
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: backgroundColor ?? defaultBg,
            prefixIcon: prefixWidget != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: prefixWidget,
                    ),
                  )
                : (prefixIcon != null
                      ? Icon(prefixIcon, size: 18, color: defaultLabelColor)
                      : null),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon:
                suffix ??
                (showClearButton &&
                        controller != null &&
                        controller!.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: defaultHintColor,
                        ),
                        onPressed: () {
                          controller!.clear();
                          onChanged?.call('');
                        },
                      )
                    : null),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: defaultBorderColor, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: defaultBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.statusDanger,
                width: 1.0,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.statusDanger,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// حقل قائمة منسدلة موحد بتصميم آبل (Apple Style Dropdown Field)
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? initialValue;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final String? hint;

  final String? Function(T?)? validator;
  final AutovalidateMode? autovalidateMode;

  const AppDropdownField({
    super.key,
    required this.label,
    this.initialValue,
    this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.hint,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? AppColors.darkSurfaceMuted
        : AppColors.surfaceWhite;
    final defaultTextColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final defaultLabelColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final defaultHintColor = isDark
        ? AppColors.darkTextTertiary
        : AppColors.textTertiary;
    final defaultBorderColor = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;
    final defaultBlue = isDark
        ? AppColors.darkPrimaryBlue
        : AppColors.primaryBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: defaultLabelColor,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value ?? initialValue,
          isExpanded: true,
          validator: validator,
          autovalidateMode: autovalidateMode,
          items: items.map((item) {
            final child = item.child;
            Widget styledChild;
            if (child is Text) {
              if (child.textSpan != null) {
                styledChild = DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                  child: child,
                );
              } else {
                styledChild = Text(
                  child.data ?? '',
                  style: (child.style ?? const TextStyle()).copyWith(
                    fontFamily: AppTheme.fontFamily,
                  ),
                  strutStyle: child.strutStyle,
                  textAlign: child.textAlign,
                  textDirection: child.textDirection,
                  locale: child.locale,
                  softWrap: child.softWrap,
                  overflow: child.overflow ?? TextOverflow.ellipsis,
                  textScaler: child.textScaler,
                  maxLines: child.maxLines ?? 1,
                  semanticsLabel: child.semanticsLabel,
                  textWidthBasis: child.textWidthBasis,
                  textHeightBehavior: child.textHeightBehavior,
                  selectionColor: child.selectionColor,
                );
              }
            } else {
              styledChild = DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: AppTheme.fontFamily),
                child: child,
              );
            }
            return DropdownMenuItem<T>(
              key: item.key,
              value: item.value,
              enabled: item.enabled,
              alignment: item.alignment,
              onTap: item.onTap,
              child: styledChild,
            );
          }).toList(),
          onChanged: onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: defaultLabelColor,
          ),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: defaultTextColor,
            fontFamily: AppTheme.fontFamily,
          ),
          dropdownColor: isDark
              ? AppColors.darkSurfaceCard
              : AppColors.surfaceWhite,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: defaultHintColor,
              fontFamily: AppTheme.fontFamily,
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.statusDanger,
              fontFamily: AppTheme.fontFamily,
            ),
            errorMaxLines: 2,
            filled: true,
            fillColor: defaultBg,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: defaultLabelColor)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: defaultBorderColor, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: defaultBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.statusDanger,
                width: 1.0,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.statusDanger,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// حقل اختيار التاريخ والوقت بتصميم آبل (Apple Date/Time Selector Field)
class AppDateSelectorField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onTap;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onClear;

  const AppDateSelectorField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
    this.isSelected = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? AppColors.darkSurfaceMuted
        : AppColors.surfaceWhite;
    final defaultLabelColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final defaultBorderColor = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;
    final defaultBlue = isDark
        ? AppColors.darkPrimaryBlue
        : AppColors.primaryBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: defaultLabelColor,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: defaultBg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? defaultBlue : defaultBorderColor,
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? defaultBlue : defaultLabelColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      valueText,

                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary)
                            : (isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary),
                      ),
                    ),
                  ),
                  if (isSelected && onClear != null)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    const ForwardChevron(size: 13),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// عنصر تبديل متوافق مع نمط آبل (Apple Switch Tile)
class AppSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Color? activeColor;

  const AppSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? AppColors.darkSurfaceCard
        : AppColors.surfaceWhite;
    final defaultBorder = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;
    final defaultBlue = isDark
        ? AppColors.darkPrimaryBlue
        : AppColors.primaryBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: defaultBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: defaultBorder, width: 0.8),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (activeColor ?? defaultBlue).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: activeColor ?? defaultBlue),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor:
                activeColor ??
                (isDark ? AppColors.darkPrimaryGreen : AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }
}
