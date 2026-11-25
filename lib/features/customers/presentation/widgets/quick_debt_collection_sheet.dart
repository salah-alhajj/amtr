import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';
import '../../../orders/domain/services/order_business_service.dart';
import 'settle_partial_debt_sheet.dart';

/// نافذة سريعة لاستلام دفعات الديون المعلقة مباشرة من الشاشة الرئيسية
class QuickDebtCollectionSheet extends StatefulWidget {
  const QuickDebtCollectionSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showAppModalSheet<bool>(
      context: context,
      title: 'quick_debt_sheet_title'.i18n(),
      subtitle: 'quick_debt_sheet_subtitle'.i18n(),
      child: const QuickDebtCollectionSheet(),
    );
  }

  @override
  State<QuickDebtCollectionSheet> createState() =>
      _QuickDebtCollectionSheetState();
}

class _QuickDebtCollectionSheetState extends State<QuickDebtCollectionSheet> {
  final OrderBusinessService _orderService = AppServices.instance.orderService;
  List<IndividualOrder> _unpaidOrders = const [];
  bool _isLoading = true;
  bool _didCollect = false;

  @override
  void initState() {
    super.initState();
    _loadUnpaidOrders();
  }

  Future<void> _loadUnpaidOrders() async {
    try {
      final unpaid = await _orderService.loadUnpaidOrdersForCollection(
        returnedCourierStatus: AppConstants.courierStatusReturned,
      );
      if (!mounted) return;
      setState(() {
        _unpaidOrders = unpaid;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _collectOrderDebt(IndividualOrder order) async {
    await SettlePartialDebtSheet.show(
      context,
      order: order,
      onConfirmPayment: (amountPaid, newStatus) async {
        await _orderService.collectOrderPayment(
          order: order,
          amountPaid: amountPaid,
          newStatus: newStatus,
        );
        _didCollect = true;
        if (!mounted) return;
        AppToast.showSuccess(
          context,
          'customer_order_payment_msg'.trParams({
            'amount': amountPaid.toStringAsFixed(0),
            'number': order.orderNumber,
          }),
          title: 'customer_payment_success'.i18n(),
        );
      },
    );
    if (!mounted) return;
    await _loadUnpaidOrders();
    if (mounted && _didCollect && _unpaidOrders.isEmpty) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.62;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_unpaidOrders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyStateView(
              icon: Icons.check_circle_outline_rounded,
              title: 'quick_debt_empty_title'.i18n(),
              subtitle: 'quick_debt_empty_subtitle'.i18n(),
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: 'common_done'.i18n(),
              onPressed: () => Navigator.pop(context, _didCollect),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _unpaidOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final order = _unpaidOrders[index];
                final customerTitle =
                    (order.customerName != null &&
                            order.customerName!.trim().isNotEmpty)
                        ? order.customerName!.trim()
                        : 'quick_order_customer_walkin'.i18n();
                return AppCard(
                  onTap: () => _collectOrderDebt(order),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppColors.primaryGreen.withValues(alpha: 0.12),
                        child: const Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'order_number'.trParams({'id': order.orderNumber}),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${'quick_debt_remaining_label'.i18n()} ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.textSecondary,
                                  ),
                                ),
                                Flexible(
                                  child: CurrencyPriceDisplay(
                                    amount: order.remainingDebt,
                                    currency: order.currency,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.statusDanger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () => _collectOrderDebt(order),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              AppColors.primaryGreen.withValues(alpha: 0.14),
                          foregroundColor: AppColors.primaryGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'quick_debt_collect_btn'.i18n(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          AppOutlinedButton(
            label: 'common_done'.i18n(),
            onPressed: () => Navigator.pop(context, _didCollect),
          ),
        ],
      ),
    );
  }
}
