import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';
import '../../domain/customer_financial_helper.dart';
import '../../domain/customer_whatsapp_helper.dart';
import '../../../../core/utils/yemen_phone_helper.dart';

/// بطاقة عرض بيانات العميل مع أزرار الاتصال والتعديل السريع بتصميم آبل التفاعلي
class CustomerCard extends StatelessWidget {
  final Customer customer;
  final CustomerFinancialSummary? summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const CustomerCard({
    super.key,
    required this.customer,
    this.summary,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0.15),
                  AppColors.primaryGreen.withValues(alpha: 0.15),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0] : 'ع',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      customer.phone != null
                          ? (YemenPhoneHelper.formatForDisplay(customer.phone) ?? customer.phone!)
                          : 'customer_no_phone'.i18n(),
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                    if (customer.whatsapp != null && customer.whatsapp!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      const WhatsAppIcon(size: 13),
                    ],
                  ],
                ),
                if (summary != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (summary!.debtsOwed > 0.001) ...[
                        AppBadge(
                          label: '${'customer_badge_debt'.i18n()}: ${CurrencyService.instance.formatAmount(summary!.debtsOwed, currencyCode: summary!.activeCurrency)}',
                          color: AppColors.statusDanger,
                          icon: Icons.trending_down_rounded,
                          fontSize: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      ],
                      if (summary!.creditBalance > 0.001) ...[
                        AppBadge(
                          label: '${'customer_badge_creditor'.i18n()}: ${CurrencyService.instance.formatAmount(summary!.creditBalance, currencyCode: summary!.activeCurrency)}',
                          color: AppColors.statusInfo,
                          icon: Icons.account_balance_wallet_rounded,
                          fontSize: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      ],
                      if (summary!.pendingOrdersCount > 0) ...[
                        AppBadge(
                          label: 'customer_badge_pending_orders'.trParams({
                            'count': summary!.pendingOrdersCount.toString(),
                          }),
                          color: AppColors.statusWarning,
                          icon: Icons.hourglass_top_rounded,
                          fontSize: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      ],
                      if (summary!.allOrdersCount == 0) ...[
                        AppBadge(
                          label: 'customer_badge_no_orders'.i18n(),
                          color: AppColors.textSecondary,
                          icon: Icons.person_outline,
                          fontSize: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if ((customer.whatsapp != null && customer.whatsapp!.isNotEmpty) ||
              (customer.phone != null && customer.phone!.isNotEmpty)) ...[
            AppIconButton(
              customIcon: const WhatsAppIcon(size: 18),
              color: AppColors.primaryGreen,
              size: 34,
              tooltip: 'customer_whatsapp_btn'.i18n(),
              onPressed: () => CustomerWhatsAppHelper.launchChat(
                context: context,
                customer: customer,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (customer.phone != null && customer.phone!.isNotEmpty) ...[
            AppIconButton(
              icon: Icons.phone_outlined,
              color: AppColors.primaryBlue,
              size: 34,
              iconSize: 16,
              tooltip: 'customer_call_btn'.i18n(),
              onPressed: () => launchUrl(Uri.parse('tel:${YemenPhoneHelper.cleanForDialing(customer.phone)}')),
            ),
            const SizedBox(width: 6),
          ],
          AppIconButton(
            icon: Icons.edit_outlined,
            color: AppColors.textSecondary,
            size: 34,
            iconSize: 16,
            tooltip: 'common_edit'.i18n(),
            onPressed: onEdit,
          ),
          const SizedBox(width: 6),
          const ForwardChevron(),
        ],
      ),
    );
  }
}
