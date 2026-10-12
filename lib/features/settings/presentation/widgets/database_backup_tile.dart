import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/apple_widgets.dart';

/// بطاقة الوصول السريع لإدارة النسخ الاحتياطي وقاعدة البيانات
class DatabaseBackupTile extends StatelessWidget {
  final VoidCallback onTap;

  const DatabaseBackupTile({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleCard(
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: context.isDarkMode
              ? AppColors.primaryBlue.withValues(alpha: 0.15)
              : const Color(0xFFE0F2FE),
          child: const Icon(Icons.backup_outlined, color: AppColors.primaryBlue),
        ),
        title: Text(
          'settings_backup_title'.i18n(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'settings_backup_desc'.i18n(),
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const ForwardChevron(),
      ),
    );
  }
}
