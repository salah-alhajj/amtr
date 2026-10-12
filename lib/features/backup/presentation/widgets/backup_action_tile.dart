import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// بطاقة خيار نسخ احتياطي أو استعادة بيانات
class BackupActionTile extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color avatarBgColor;
  final String title;
  final String subtitle;

  const BackupActionTile({
    super.key,
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.avatarBgColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = context.isDarkMode
        ? iconColor.withValues(alpha: 0.15)
        : avatarBgColor;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: effectiveBg,
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const ForwardChevron(),
      ),
    );
  }
}
