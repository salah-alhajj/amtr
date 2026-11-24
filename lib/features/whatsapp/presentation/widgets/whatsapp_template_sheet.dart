import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';
import '../../../customers/data/repositories/customer_repository_impl.dart';
import '../../../customers/domain/customer_whatsapp_helper.dart';
import '../../data/whatsapp_template_repository.dart';
import '../../domain/whatsapp_template_engine.dart';

/// ورقة سفلية لاختيار وتعديل وإرسال رسائل واتساب المُلطّفة للطلب
class WhatsAppTemplateSheet extends StatefulWidget {
  static const String typePreDispatchCod = 'pre_dispatch_cod';

  final IndividualOrder order;
  final String initialType;
  final String? customerPhone;

  const WhatsAppTemplateSheet({
    super.key,
    required this.order,
    this.initialType = WhatsAppTemplateEngine.typeConfirmDeposit,
    this.customerPhone,
  });

  static Future<void> show(
    BuildContext context, {
    required IndividualOrder order,
    String initialType = WhatsAppTemplateEngine.typeConfirmDeposit,
    String? customerPhone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WhatsAppTemplateSheet(
        order: order,
        initialType: initialType,
        customerPhone: customerPhone,
      ),
    );
  }

  @override
  State<WhatsAppTemplateSheet> createState() => _WhatsAppTemplateSheetState();
}

class _WhatsAppTemplateSheetState extends State<WhatsAppTemplateSheet> {
  static const List<String> _sheetTemplateTypes = [
    ...WhatsAppTemplateEngine.templateTypes,
    WhatsAppTemplateSheet.typePreDispatchCod,
  ];

  final WhatsAppTemplateRepository _templateRepo = WhatsAppTemplateRepository();
  final CustomerRepositoryImpl _customerRepo = CustomerRepositoryImpl();
  late final TextEditingController _messageController;

  late String _selectedType;
  String _selectedTone = WhatsAppTemplateEngine.toneWarm;
  String? _resolvedPhone;
  String? _resolvedCustomerName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedType = _sheetTemplateTypes.contains(widget.initialType)
        ? widget.initialType
        : WhatsAppTemplateEngine.typeConfirmDeposit;
    _resolvedPhone = widget.customerPhone;
    _resolvedCustomerName = widget.order.customerName;
    _messageController = TextEditingController();
    _renderCurrentMessage();
    _loadCustomerAndTemplate();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerAndTemplate() async {
    if ((_resolvedPhone == null || _resolvedPhone!.trim().isEmpty) &&
        widget.order.customerId != null &&
        widget.order.customerId!.isNotEmpty) {
      final customer = await _customerRepo.getCustomerById(widget.order.customerId!);
      if (customer != null && mounted) {
        _resolvedPhone = CustomerWhatsAppHelper.getEffectiveWhatsAppNumber(customer);
        if (_resolvedCustomerName == null || _resolvedCustomerName!.trim().isEmpty) {
          _resolvedCustomerName = customer.name;
        }
      }
    }
    await _renderCurrentMessage();
  }

  Future<void> _renderCurrentMessage() async {
    if (_selectedType == WhatsAppTemplateSheet.typePreDispatchCod) {
      final orderForMessage =
          (_resolvedCustomerName != null &&
              _resolvedCustomerName!.trim().isNotEmpty &&
              (widget.order.customerName == null ||
                  widget.order.customerName!.trim().isEmpty))
          ? widget.order.copyWith(customerName: _resolvedCustomerName)
          : widget.order;
      if (!mounted) return;
      _messageController.text =
          WhatsAppTemplateEngine.buildPreDispatchCodConfirmMessage(
            orderForMessage,
          );
      return;
    }

    final stored = await _templateRepo.getTemplate(
      _selectedType,
      tone: _selectedType == WhatsAppTemplateEngine.typeReminder
          ? _selectedTone
          : WhatsAppTemplateEngine.toneWarm,
    );
    if (!mounted) return;
    final rendered = WhatsAppTemplateEngine.renderOrderMessage(
      order: widget.order,
      type: _selectedType,
      tone: _selectedTone,
      customBody: stored?.body,
      customerName: _resolvedCustomerName,
    );
    _messageController.text = rendered;
  }

  String _typeLabel(String type) {
    switch (type) {
      case WhatsAppTemplateEngine.typeConfirmDeposit:
        return 'wa_tpl_confirm'.i18n();
      case WhatsAppTemplateEngine.typeReady:
        return 'wa_tpl_ready'.i18n();
      case WhatsAppTemplateEngine.typeReminder:
        return 'wa_tpl_reminder'.i18n();
      case WhatsAppTemplateEngine.typeThanks:
        return 'wa_tpl_thanks'.i18n();
      case WhatsAppTemplateSheet.typePreDispatchCod:
        return 'wa_tpl_pre_dispatch_cod'.i18n();
      default:
        return type;
    }
  }

  String _toneLabel(String tone) {
    switch (tone) {
      case WhatsAppTemplateEngine.toneWarm:
        return 'wa_tone_warm'.i18n();
      case WhatsAppTemplateEngine.tonePolite:
        return 'wa_tone_polite'.i18n();
      case WhatsAppTemplateEngine.toneFormal:
        return 'wa_tone_formal'.i18n();
      default:
        return tone;
    }
  }

  Future<void> _copyMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      AppToast.showSuccess(context, 'wa_copied_success'.i18n());
    }
  }

  Future<void> _sendViaWhatsApp() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      String cleanPhone = YemenPhoneHelper.cleanForWhatsApp(_resolvedPhone);
      if (cleanPhone.isEmpty &&
          widget.order.customerId != null &&
          widget.order.customerId!.isNotEmpty) {
        final customer = await _customerRepo.getCustomerById(widget.order.customerId!);
        if (customer != null) {
          cleanPhone = CustomerWhatsAppHelper.getEffectiveWhatsAppNumber(customer);
        }
      }
      cleanPhone = YemenPhoneHelper.cleanForWhatsApp(cleanPhone);

      final encodedText = Uri.encodeComponent(text);
      final nativeUri = cleanPhone.isNotEmpty
          ? Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedText')
          : Uri.parse('whatsapp://send?text=$encodedText');
      final webUri = cleanPhone.isNotEmpty
          ? Uri.parse('https://wa.me/$cleanPhone?text=$encodedText')
          : Uri.parse('https://wa.me/?text=$encodedText');

      bool launched = false;
      try {
        if (await canLaunchUrl(nativeUri)) {
          launched = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        launched = false;
      }

      if (!launched) {
        try {
          if (await canLaunchUrl(webUri)) {
            launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
          } else {
            launched = await launchUrl(webUri, mode: LaunchMode.platformDefault);
          }
        } catch (_) {
          launched = false;
        }
      }

      if (!launched && mounted) {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          AppToast.showInfo(context, 'wa_copied_success'.i18n());
        }
      } else if (launched && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalSheet(
      title: 'wa_templates_title'.i18n(),
      subtitle: '#${widget.order.orderNumber}',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sheetTemplateTypes.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(_typeLabel(type)),
                  selected: isSelected,
                  selectedColor: AppColors.primaryGreen.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primaryGreen : context.textPrimary,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedType = type);
                    _renderCurrentMessage();
                  },
                );
              }).toList(),
            ),
            if (_selectedType == WhatsAppTemplateEngine.typeReminder) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WhatsAppTemplateEngine.reminderTones.map((tone) {
                  final isSelected = _selectedTone == tone;
                  return ChoiceChip(
                    label: Text(_toneLabel(tone)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBlue.withValues(alpha: 0.16),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primaryBlue : context.textPrimary,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedTone = tone);
                      _renderCurrentMessage();
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'wa_edit_message_label'.i18n(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 7,
              minLines: 5,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                filled: true,
                fillColor: context.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.borderDivider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.borderDivider),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'wa_copy_btn'.i18n(),
                    icon: Icons.copy_outlined,
                    variant: AppButtonVariant.ghost,
                    onPressed: _copyMessage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'wa_send_btn'.i18n(),
                    icon: Icons.send_outlined,
                    isLoading: _isSending,
                    onPressed: _sendViaWhatsApp,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
