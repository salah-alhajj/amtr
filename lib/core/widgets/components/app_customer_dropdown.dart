import 'package:flutter/material.dart';
import '../../../models/customer.dart';
import '../../localization/localization.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/yemen_phone_helper.dart';
import '../../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../../features/customers/presentation/widgets/add_edit_customer_sheet.dart';
import '../whatsapp_icon.dart';
import 'app_buttons.dart';
import 'app_text_fields.dart';

/// قائمة منسدلة تفاعلية ومخصصة لاختيار والبحث عن عميل مسجل بالاسم أو الهاتف
/// مطابقة لمفاهيم ومعايير نظام تصميم آبل الموحد لتطبيق مساعد،
/// مع إمكانية إنشاء عميل جديد مباشرة عبر نفس البوتوم شيت واختياره فورياً.
class AppCustomerSearchDropdown extends StatelessWidget {
  final String? selectedCustomerId;
  final List<Customer> customers;
  final ValueChanged<Customer?> onChanged;
  final ValueChanged<Customer>? onCustomerCreated;
  final String? label;
  final bool isRequired;
  final String? Function(String?)? validator;

  const AppCustomerSearchDropdown({
    super.key,
    required this.selectedCustomerId,
    required this.customers,
    required this.onChanged,
    this.onCustomerCreated,
    this.label,
    this.isRequired = false,
    this.validator,
  });

  Customer? get _selectedCustomer {
    if (selectedCustomerId == null || selectedCustomerId!.isEmpty) return null;
    try {
      return customers.firstWhere((c) => c.id == selectedCustomerId);
    } catch (_) {
      return null;
    }
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<Customer?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerSearchPickerSheet(
        customers: customers,
        currentSelectedId: selectedCustomerId,
        onCustomerCreated: onCustomerCreated,
      ),
    ).then((selected) {
      if (selected != null) {
        // إذا تم اختيار عميل من القائمة (معرّف فارغ يعني إلغاء الربط)
        if (selected.id.isEmpty) {
          onChanged(null);
        } else {
          onChanged(selected);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customer = _selectedCustomer;
    final hasSelection = customer != null;

    final defaultBg = isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceWhite;
    final defaultBorderColor = isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
    final defaultLabelColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label ?? 'order_link_registered_customer'.i18n(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: defaultLabelColor,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            if (!hasSelection)
              GestureDetector(
                onTap: () => _openPicker(context),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 14, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      'customer_add_new_btn'.i18n(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: defaultBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasSelection ? AppColors.primaryBlue.withValues(alpha: 0.5) : defaultBorderColor,
                width: hasSelection ? 1.2 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // أفاتار العميل أو أيقونة البحث
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? AppColors.primaryBlue.withValues(alpha: 0.12)
                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: hasSelection
                        ? Text(
                            customer.name.isNotEmpty
                                ? customer.name[0].toUpperCase()
                                : (context.isArabic ? 'ع' : 'C'),
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          )
                        : Icon(
                            Icons.person_search_rounded,
                            size: 18,
                            color: defaultLabelColor,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // بيانات العميل المختار أو رسالة الاسترشاد
                Expanded(
                  child: hasSelection
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                            if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    YemenPhoneHelper.formatForDisplay(customer.phone, context: context) ?? customer.phone!,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.textSecondary,
                                      fontFamily: AppTheme.fontFamily,
                                    ),
                                  ),
                                  if (customer.whatsapp != null && customer.whatsapp!.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    const WhatsAppIcon(size: 12),
                                  ],
                                ],
                              ),
                            ] else if (customer.whatsapp != null && customer.whatsapp!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const WhatsAppIcon(size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    YemenPhoneHelper.formatForDisplay(customer.whatsapp, context: context) ?? customer.whatsapp!,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primaryGreen,
                                      fontFamily: AppTheme.fontFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        )
                      : Text(
                          'customer_search_or_select'.i18n(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textTertiary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                ),
                // أزرار التحكم الجانبية (إلغاء الربط أو سهم الفتح)
                if (hasSelection) ...[
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: context.textSecondary,
                    tooltip: 'customer_unlinked_option'.i18n(),
                    onPressed: () => onChanged(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  Icons.unfold_more_rounded,
                  size: 20,
                  color: context.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// البوتوم شيت التفاعلية المخصصة للبحث المباشر عن العملاء وإضافة عميل جديد
class _CustomerSearchPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final String? currentSelectedId;
  final ValueChanged<Customer>? onCustomerCreated;

  const _CustomerSearchPickerSheet({
    required this.customers,
    this.currentSelectedId,
    this.onCustomerCreated,
  });

  @override
  State<_CustomerSearchPickerSheet> createState() => _CustomerSearchPickerSheetState();
}

class _CustomerSearchPickerSheetState extends State<_CustomerSearchPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<Customer> _allCustomers;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allCustomers = List.from(widget.customers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Customer> get _filteredCustomers {
    if (_query.trim().isEmpty) return _allCustomers;
    final cleanQuery = _query.trim().toLowerCase();
    final convertedQuery = YemenPhoneHelper.convertArabicIndicDigits(cleanQuery);
    final cleanPhoneQuery = convertedQuery.replaceAll(RegExp(r'[^0-9]'), '');

    return _allCustomers.where((c) {
      final nameMatches = c.name.toLowerCase().contains(cleanQuery);
      final phoneDigits = c.phone != null
          ? YemenPhoneHelper.convertArabicIndicDigits(c.phone!).replaceAll(RegExp(r'[^0-9]'), '')
          : '';
      final waDigits = c.whatsapp != null
          ? YemenPhoneHelper.convertArabicIndicDigits(c.whatsapp!).replaceAll(RegExp(r'[^0-9]'), '')
          : '';

      final phoneMatches = cleanPhoneQuery.isNotEmpty && phoneDigits.contains(cleanPhoneQuery);
      final waMatches = cleanPhoneQuery.isNotEmpty && waDigits.contains(cleanPhoneQuery);

      return nameMatches || phoneMatches || waMatches;
    }).toList();
  }

  Future<void> _handleAddNewCustomer() async {
    await AddEditCustomerSheet.show(
      context,
      onSave: (newCustomer) async {
        // حفظ العميل في قاعدة البيانات المحلية
        final repo = CustomerRepositoryImpl();
        await repo.saveCustomer(newCustomer);

        if (!mounted) return;

        setState(() {
          _allCustomers.insert(0, newCustomer);
        });

        widget.onCustomerCreated?.call(newCustomer);

        // إرجاع العميل المنشأ حديثاً مباشرة ليتم اختياره فوراً في شاشة الطلب
        Navigator.pop(context, newCustomer);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredCustomers;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض السحب العلوي (Apple Pull Handle)
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ترويسة الشيت مع زر الإضافة وزر الإغلاق
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'order_link_registered_customer'.i18n(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_allCustomers.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // شريط البحث المباشر وزر إنشاء عميل جديد
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchCtrl,
                    hint: 'customer_search_hint'.i18n(),
                    prefixIcon: Icons.search_rounded,
                    showClearButton: true,
                    onChanged: (val) => setState(() => _query = val),
                  ),
                ),
                const SizedBox(width: 10),
                AppSecondaryButton(
                  label: 'customer_add_new_btn'.i18n(),
                  icon: Icons.person_add_rounded,
                  color: AppColors.primaryBlue,
                  height: 48,
                  onPressed: _handleAddNewCustomer,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // خيار إلغاء الربط (عميل سريع)
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: context.textSecondary,
              ),
            ),
            title: Text(
              'customer_unlinked_option'.i18n(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            trailing: widget.currentSelectedId == null || widget.currentSelectedId!.isEmpty
                ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20)
                : null,
            onTap: () => Navigator.pop(context, Customer(id: '', name: '')),
          ),

          const Divider(height: 1),

          // قائمة نتائج العملاء
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: context.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 10),
                        Text(
                          'customer_no_search_results'.i18n(),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        if (_query.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          AppSecondaryButton(
                            label: context.isArabic
                                ? 'إضافة عميل باسم "$_query"'
                                : 'Add customer "$_query"',
                            icon: Icons.add_rounded,
                            onPressed: _handleAddNewCustomer,
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                    itemBuilder: (ctx, index) {
                      final c = filtered[index];
                      final isSelected = c.id == widget.currentSelectedId;

                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              c.name.isNotEmpty
                                  ? c.name[0].toUpperCase()
                                  : (context.isArabic ? 'ع' : 'C'),
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.primaryBlue : context.textPrimary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        subtitle: (c.phone != null && c.phone!.isNotEmpty) ||
                                (c.whatsapp != null && c.whatsapp!.isNotEmpty)
                            ? Row(
                                children: [
                                   if (c.phone != null && c.phone!.isNotEmpty) ...[
                                    Text(
                                      YemenPhoneHelper.formatForDisplay(c.phone, context: context) ?? c.phone!,
                                      textDirection: TextDirection.ltr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textSecondary,
                                        fontFamily: AppTheme.fontFamily,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (c.whatsapp != null && c.whatsapp!.isNotEmpty) ...[
                                    const WhatsAppIcon(size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      YemenPhoneHelper.formatForDisplay(c.whatsapp, context: context) ?? c.whatsapp!,
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: AppTheme.fontFamily,
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 22)
                            : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
