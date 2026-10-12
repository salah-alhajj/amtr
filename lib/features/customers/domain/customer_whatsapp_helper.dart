import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants.dart';
import '../../../core/widgets/design_system.dart';
import '../../../models/customer.dart';
import '../../../models/individual_order.dart';

import '../../../core/utils/yemen_phone_helper.dart';

/// مساعد إدارة وتنسيق رسائل واتساب مع العملاء
class CustomerWhatsAppHelper {
  /// تنظيف وتجهيز رقم الهاتف بصيغة دولية موحدة للواتساب تدعم اليمن والأرقام الدولية
  static String cleanPhoneNumber(String? raw) {
    return YemenPhoneHelper.cleanForWhatsApp(raw);
  }

  /// الحصول على الرقم المعتمد للواتساب (رقم الواتساب أولاً، ثم الهاتف كبديل)
  static String getEffectiveWhatsAppNumber(Customer customer) {
    if (customer.whatsapp != null && customer.whatsapp!.trim().isNotEmpty) {
      return cleanPhoneNumber(customer.whatsapp);
    }
    return cleanPhoneNumber(customer.phone);
  }

  /// بناء نص رسالة حالة طلب فردي مفصل
  static String buildSingleOrderStatusMessage({
    required Customer customer,
    required IndividualOrder order,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله وبركاته 🌸');
    buffer.writeln('مرحباً أخي/أختي: *${customer.name}*');
    buffer.writeln('تفاصيل ومتابعة حالة طلبكم رقم: *#${order.orderNumber}*');
    buffer.writeln('--------------------------------');
    buffer.writeln('📦 *حالة الطلب:* ${AppConstants.getOrderStatusLabel(order.orderStatus)}');
    buffer.writeln('💳 *حالة السداد:* ${AppConstants.getPaymentStatusLabel(order.paymentStatus)}');
    buffer.writeln('🗓️ *تاريخ الطلب:* ${order.createdAt.year}/${order.createdAt.month}/${order.createdAt.day}');

    if (order.items.isNotEmpty) {
      buffer.writeln('\n📋 *الأغراض والمنتجات (${order.items.length}):*');
      for (int i = 0; i < order.items.length; i++) {
        final it = order.items[i];
        final priceText = it.sellPrice != null
            ? '${it.totalSell!.toStringAsFixed(0)} ${AppConstants.getCurrencySymbol(order.currency)}'
            : 'قيد التسعير';
        buffer.writeln('${i + 1}. ${it.name} (الكمية: ${it.quantity}) - $priceText');
      }
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('💰 *إجمالي المطلوب:* ${order.totalSellPrice.toStringAsFixed(0)} ${AppConstants.getCurrencySymbol(order.currency)}');
    buffer.writeln('💵 *المسدد:* ${order.paidAmount.toStringAsFixed(0)} ${AppConstants.getCurrencySymbol(order.currency)}');

    if (order.remainingDebt > 0) {
      buffer.writeln('📌 *المتبقي كدين:* *${order.remainingDebt.toStringAsFixed(0)} ${AppConstants.getCurrencySymbol(order.currency)}*');
      if (order.debtDueDate != null) {
        buffer.writeln('⏰ *موعد استحقاق السداد:* ${order.debtDueDate!.year}/${order.debtDueDate!.month}/${order.debtDueDate!.day}');
      }
    } else if (order.totalSellPrice > 0 && order.paidAmount >= order.totalSellPrice) {
      buffer.writeln('✅ *الحالة المالية:* مسدد بالكامل، شكراً لكم');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('يسعدنا دائماً خدمتكم، دمتم بخير ✨');
    return buffer.toString();
  }

  /// بناء نص كشف حالة مجموعة طلبات محددة
  static String buildMultipleOrdersStatusMessage({
    required Customer customer,
    required List<IndividualOrder> selectedOrders,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('السلام عليكم ورحمة الله وبركاته 🌸');
    buffer.writeln('مرحباً *${customer.name}*');
    buffer.writeln('إليك كشف ومتابعة حالة الطلبات المحددة (*${selectedOrders.length} طلبات*):');
    buffer.writeln('================================');

    double totalSales = 0.0;
    double totalPaid = 0.0;
    double totalRemaining = 0.0;

    for (int i = 0; i < selectedOrders.length; i++) {
      final o = selectedOrders[i];
      totalSales += o.totalSellPrice;
      totalPaid += o.paidAmount;
      totalRemaining += o.remainingDebt;

      final currSymbol = AppConstants.getCurrencySymbol(o.currency);

      buffer.writeln('${i + 1}️⃣ *طلب #${o.orderNumber}*');
      buffer.writeln('   • الحالة: ${AppConstants.getOrderStatusLabel(o.orderStatus)} | السداد: ${AppConstants.getPaymentStatusLabel(o.paymentStatus)}');
      buffer.writeln('   • المطلوب: ${o.totalSellPrice.toStringAsFixed(0)} $currSymbol | المسدد: ${o.paidAmount.toStringAsFixed(0)} $currSymbol');
      if (o.remainingDebt > 0) {
        buffer.writeln('   • 📌 المتبقي: *${o.remainingDebt.toStringAsFixed(0)} $currSymbol*');
      } else {
        buffer.writeln('   • ✅ مسدد بالكامل');
      }
      buffer.writeln('--------------------------------');
    }

    buffer.writeln('📊 *الإجمالي العام للطلبات المحددة:*');
    buffer.writeln('💰 *إجمالي المبيعات:* ${totalSales.toStringAsFixed(0)}');
    buffer.writeln('💵 *إجمالي المسدد:* ${totalPaid.toStringAsFixed(0)}');
    buffer.writeln('📌 *صافي المتبقي:* *${totalRemaining.toStringAsFixed(0)}*');
    buffer.writeln('================================');
    buffer.writeln('شاكرين ومقدرين حسن تعاملكم معنا ✨');

    return buffer.toString();
  }

  /// فتح محادثة الواتساب مع العميل مباشرة مع إرسال النص اختارياً
  static Future<void> launchChat({
    required BuildContext context,
    required Customer customer,
    String? message,
  }) async {
    final cleanPhone = getEffectiveWhatsAppNumber(customer);

    if (cleanPhone.isEmpty) {
      AppToast.showWarning(
        context,
        'لا يوجد رقم هاتف أو واتساب مسجل لهذا العميل',
        title: 'واتساب',
      );
      return;
    }

    final encodedText = message != null ? Uri.encodeComponent(message) : '';
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone${encodedText.isNotEmpty ? '&text=$encodedText' : ''}');
    final webUri = Uri.parse('https://wa.me/$cleanPhone${encodedText.isNotEmpty ? '?text=$encodedText' : ''}');

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return;
      }

      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }

      // إذا لم يتوفر تطبيق واتساب أو المتصفح الخارجي
      if (message != null && message.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: message));
        if (context.mounted) {
          AppToast.showInfo(
            context,
            'تم نسخ نص الرسالة إلى الحافظة لعدم توفر تطبيق واتساب مباشرة',
            title: 'تم النسخ',
          );
        }
      }
    } catch (e) {
      if (message != null && message.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: message));
        if (context.mounted) {
          AppToast.showInfo(
            context,
            'تم نسخ التقرير إلى الحافظة',
            title: 'تم النسخ',
          );
        }
      }
    }
  }
}
