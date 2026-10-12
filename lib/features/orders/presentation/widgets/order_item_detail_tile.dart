import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/order_item.dart';

/// بطاقة عرض تفاصيل الغرض أو البند الفردي في شاشة تفاصيل الطلب
class OrderItemDetailTile extends StatelessWidget {
  final OrderItem item;

  const OrderItemDetailTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService.instance;

    return AppleCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'item_qty_fmt'.trParams({'qty': item.quantity.toString()}),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.description!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'item_cost_price_fmt'.trParams({
                  'price': currencyService.formatAmount(
                    item.costPrice,
                    currencyCode: item.currency,
                  ),
                }),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                item.sellPrice != null
                    ? 'item_sell_price_fmt'.trParams({
                        'price': currencyService.formatAmount(
                          item.sellPrice!,
                          currencyCode: item.currency,
                        ),
                      })
                    : 'item_sell_price_unset'.i18n(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: item.sellPrice != null
                      ? AppColors.primaryGreen
                      : AppColors.statusWarning,
                ),
              ),
            ],
          ),

          // معرض الصور المصغرة للبند مع إمكانية التكبير والمعاينة
          if (item.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            AppPhotoAttachmentSection(
              photos: item.photos,
              onPhotosChanged: (_) {},
              readOnly: true,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}
