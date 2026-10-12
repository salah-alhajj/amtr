import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/widgets/design_system.dart';

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
    return AppSectionHeader(
      title: title,
      actionTitle: actionLabel ?? 'view_all'.i18n(),
      onActionTap: onAction,
      padding: EdgeInsets.zero,
    );
  }
}
