import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../models/individual_order.dart';
import '../localization/localization.dart';
import '../services/currency_service.dart';

/// خدمة التذكيرات والمنبهات ومزامنة تقويم الهاتف لاستحقاق الديون
class ReminderService {
  static final ReminderService instance = ReminderService._init();
  ReminderService._init();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// تهيئة إعدادات الإشعارات والتوقيت بأمان
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(settings: initializationSettings);

      // طلب إذن الإشعارات والمنبه الدقيق لنظام أندرويد 13 فما فوق
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestExactAlarmsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[ReminderService] Notification init warning: $e');
    }
  }

  /// طلب وتأكيد أذونات الإشعارات والمنبه الدقيق (Exact Alarms) لأندرويد 13+ و iOS
  Future<bool> requestPermissions() async {
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final notif = await androidPlugin.requestNotificationsPermission();
          final alarm = await androidPlugin.requestExactAlarmsPermission();
          return (notif ?? false) || (alarm ?? false);
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('[ReminderService] Error requesting permissions: $e');
    }
    return false;
  }

  int _generateNotificationId(String orderId) {
    return orderId.hashCode.abs() % 100000;
  }

  /// جدولة منبه وتنبيه استحقاق الدين بالوقت والتاريخ الدقيق
  Future<bool> scheduleDebtReminder(IndividualOrder order) async {
    if (order.debtDueDate == null) return false;
    await requestPermissions();

    try {
      final notifId = _generateNotificationId(order.id);
      final formattedAmount = CurrencyService.instance
          .formatAmount(order.remainingDebt, currencyCode: order.currency);

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'debt_reminders_channel',
        'reminder_channel_name'.i18n(),
        channelDescription: 'reminder_channel_desc'.i18n(),
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final scheduledDate = tz.TZDateTime.from(order.debtDueDate!, tz.local);

      final title = 'reminder_notif_title'.trParams({'number': order.orderNumber});
      final body = 'reminder_notif_body'.trParams({
        'customer': order.customerName ?? 'customer_unregistered'.i18n(),
        'amount': formattedAmount,
      });

      if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
        await _notificationsPlugin.zonedSchedule(
          id: notifId,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } else {
        // إذا كان التاريخ حالياً أو فورياً
        await _notificationsPlugin.show(
          id: notifId,
          title: title,
          body: body,
          notificationDetails: platformDetails,
        );
      }
      return true;
    } catch (e) {
      debugPrint('[ReminderService] Error scheduling reminder: $e');
      return false;
    }
  }

  /// إطلاق تنبيه فوري تجريبي أو مباشر للتحقق من المنبه
  Future<void> showImmediateDebtAlarm(IndividualOrder order) async {
    await init();
    try {
      final notifId = _generateNotificationId(order.id);
      final formattedAmount = CurrencyService.instance
          .formatAmount(order.remainingDebt, currencyCode: order.currency);

      final NotificationDetails platformDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'debt_reminders_channel',
          'reminder_channel_name'.i18n(),
          channelDescription: 'reminder_channel_desc'.i18n(),
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        id: notifId,
        title: 'reminder_instant_title'.trParams({'number': order.orderNumber}),
        body: 'reminder_instant_body'.trParams({
          'customer': order.customerName ?? 'customer_unregistered'.i18n(),
          'amount': formattedAmount,
        }),
        notificationDetails: platformDetails,
      );
    } catch (e) {
      debugPrint('[ReminderService] Error showing immediate alarm: $e');
    }
  }

  /// إلغاء منبه الدين لطلب معين
  Future<void> cancelDebtReminder(String orderId) async {
    await init();
    try {
      await _notificationsPlugin.cancel(id: _generateNotificationId(orderId));
    } catch (e) {
      debugPrint('[ReminderService] Error canceling reminder: $e');
    }
  }

  /// مزامنة موعد استحقاق الدين مع التقويم المدمج في الهاتف (Apple Calendar / Google Calendar)
  Future<bool> syncWithNativeCalendar(IndividualOrder order) async {
    if (order.debtDueDate == null) return false;

    final formattedAmount = CurrencyService.instance
        .formatAmount(order.remainingDebt, currencyCode: order.currency);

    final event = Event(
      title: 'reminder_calendar_title'.trParams({
        'number': order.orderNumber,
        'customer': order.customerName ?? 'customer_default'.i18n(),
      }),
      description: 'reminder_calendar_desc'.trParams({
        'amount': formattedAmount,
        'status': order.orderStatus,
        'notes': order.notes?.isNotEmpty == true ? order.notes! : 'common_no_notes'.i18n(),
      }),
      location: order.customerName != null
          ? '${'customer_default'.i18n()}: ${order.customerName}'
          : 'reminder_calendar_location'.i18n(),
      startDate: order.debtDueDate!,
      endDate: order.debtDueDate!.add(const Duration(minutes: 30)),
      iosParams: const IOSParams(
        reminder: Duration(hours: 1),
      ),
      androidParams: const AndroidParams(),
    );

    try {
      final success = await Add2Calendar.addEvent2Cal(event);
      return success;
    } catch (e) {
      debugPrint('[ReminderService] Error adding event to calendar: $e');
      return false;
    }
  }
}
