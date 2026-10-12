import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/widgets/apple_widgets.dart';

/// رأس القسم في لوحة التحكم مع زر عرض الكل وسهم التقدم لليسار
class DashboardSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback onAction;

  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: onAction,
          child: Row(
            children: [
              Text(
                actionLabel ?? 'view_all'.i18n(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const ForwardChevron(size: 11),
            ],
          ),
        ),
      ],
    );
  }
}
