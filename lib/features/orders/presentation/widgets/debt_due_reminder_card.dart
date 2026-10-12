import 'package:amtr/core/widgets/components/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/apple_widgets.dart';
import '../../../../models/individual_order.dart';

/// بطاقة مخصصة لتحديد تاريخ ووقت استحقاق الدين وضبط المنبه ومزامنة تقويم الهاتف
class DebtDueReminderCard extends StatelessWidget {
  final DateTime? debtDueDate;
  final bool hasDebtReminder;
  final bool isSyncedWithCalendar;
  final String orderNumber;
  final String? customerName;
  final double remainingDebt;
  final String currency;
  final ValueChanged<DateTime?> onDueDateChanged;
  final ValueChanged<bool> onReminderChanged;
  final ValueChanged<bool> onCalendarSyncedChanged;

  const DebtDueReminderCard({
    super.key,
    required this.debtDueDate,
    required this.hasDebtReminder,
    required this.isSyncedWithCalendar,
    required this.orderNumber,
    required this.customerName,
    required this.remainingDebt,
    required this.currency,
    required this.onDueDateChanged,
    required this.onReminderChanged,
    required this.onCalendarSyncedChanged,
  });

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = debtDueDate ?? now.add(const Duration(days: 3));

    // 1. اختيار التاريخ
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'debt_due_pick_date'.i18n(),
      confirmText: 'debt_due_next_time'.i18n(),
    );

    if (pickedDate == null || !context.mounted) return;

    // 2. اختيار الوقت بالساعة والدقيقة بدقة
    final initialTime = debtDueDate != null
        ? TimeOfDay.fromDateTime(debtDueDate!)
        : const TimeOfDay(hour: 10, minute: 0);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'debt_due_pick_time'.i18n(),
      confirmText: 'debt_due_confirm_alarm'.i18n(),
    );

    if (pickedTime == null) return;

    final combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    onDueDateChanged(combinedDateTime);
  }

  IndividualOrder _buildTempOrder() {
    return IndividualOrder(
      id: 'temp_$orderNumber',
      orderNumber: orderNumber,
      customerName: customerName,
      debtDueDate: debtDueDate,
      currency: currency,
    );
  }

  Future<void> _syncToCalendar(BuildContext context) async {
    if (debtDueDate == null) {
      AppToast.showWarning(context, 'debt_due_specify_first'.i18n());
      return;
    }

    final tempOrder = _buildTempOrder();
    final ok = await ReminderService.instance.syncWithNativeCalendar(tempOrder);

    if (context.mounted) {
      if (ok) {
        onCalendarSyncedChanged(true);
        AppToast.showSuccess(context, 'debt_due_calendar_success'.i18n());
      } else {
        AppToast.showInfo(context, 'debt_due_calendar_cancelled'.i18n());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDueDate = debtDueDate != null
        ? DateFormat('yyyy/MM/dd  -  hh:mm a').format(debtDueDate!)
        : null;

    final currencySymbol = AppConstants.getCurrencySymbol(currency);
    final remainingFormatted = CurrencyService.instance.formatAmount(
      remainingDebt,
      currencyCode: currency,
    );

    return AppleCard(
      border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.4)),
      backgroundColor: context.isDarkMode
          ? AppColors.darkSurfaceCard
          : const Color(0xFFFFFBEB), // نغمة تحذيرية ناعمة جداً
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط العنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.statusWarning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: AppColors.statusWarning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'debt_due_card_title'.i18n(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      'debt_due_remaining_fmt'.trParams({
                        'amount': remainingFormatted,
                        'symbol': currencySymbol,
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSyncedWithCalendar)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'debt_due_synced_calendar'.i18n(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // زر تحديد التاريخ والوقت الدقيق
          Material(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _pickDateTime(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: debtDueDate != null
                        ? AppColors.statusWarning
                        : context.borderSubtle,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: debtDueDate != null
                          ? AppColors.statusWarning
                          : context.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'debt_due_datetime_label'.i18n(),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDueDate ?? 'debt_due_pick_prompt'.i18n(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: debtDueDate != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: debtDueDate != null
                                  ? context.textPrimary
                                  : context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (debtDueDate != null)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () {
                          onDueDateChanged(null);
                          onReminderChanged(false);
                          onCalendarSyncedChanged(false);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      const ForwardChevron(size: 14),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // مفتاح تفعيل المنبه الدقيق
          SwitchListTile.adaptive(
            value: hasDebtReminder,
            onChanged: debtDueDate != null
                ? (val) => onReminderChanged(val)
                : null,
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AppColors.statusWarning,
            title: Text(
              'debt_due_toggle_title'.i18n(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'debt_due_toggle_desc'.i18n(),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          Divider(height: 16, color: context.borderDivider),

          // زر المزامنة مع تقويم الهاتف
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: debtDueDate != null
                  ? () => _syncToCalendar(context)
                  : null,
              icon: const Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: AppColors.primaryBlue,
              ),
              label: Text(
                'debt_due_sync_btn'.i18n(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 12,
                ),
                side: const BorderSide(
                  color: AppColors.primaryBlue,
                  width: 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
