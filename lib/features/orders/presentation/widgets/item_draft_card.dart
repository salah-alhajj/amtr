import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// مسودة بيانات بند في نموذج إنشاء الطلب
class OrderItemDraft {
  final String id;
  String? productId;
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController costController;
  final TextEditingController sellController;
  List<String> photos;

  OrderItemDraft({
    String? id,
    this.productId,
    String? name,
    int? quantity,
    double? costPrice,
    double? sellPrice,
    List<String>? photos,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       nameController = TextEditingController(text: name ?? ''),
       qtyController = TextEditingController(text: (quantity ?? 1).toString()),
       costController = TextEditingController(
         text: costPrice != null && costPrice > 0 ? costPrice.toString() : '',
       ),
       sellController = TextEditingController(
         text: sellPrice != null ? sellPrice.toString() : '',
       ),
       photos = photos != null ? List<String>.from(photos) : [];

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    costController.dispose();
    sellController.dispose();
  }
}

/// بطاقة إدخال بيانات غرض في شاشة إضافة/تعديل الطلب
class ItemDraftCard extends StatelessWidget {
  final int index;
  final OrderItemDraft draft;
  final String currency;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback? onPickPhotos;
  final ValueChanged<int>? onRemovePhoto;
  final ValueChanged<List<String>>? onPhotosChanged;
  final bool? isProductiveFamily;

  const ItemDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.currency,
    required this.canDelete,
    required this.onDelete,
    this.onPickPhotos,
    this.onRemovePhoto,
    this.onPhotosChanged,
    this.isProductiveFamily,
  });

  Widget _buildQtyField() {
    return AppTextField(
      controller: draft.qtyController,
      keyboardType: TextInputType.number,
      label: 'item_quantity_label'.i18n(),
      prefixIcon: Icons.format_list_numbered_rounded,
      inputFormatters: AppFormatters.positiveInteger(maxDigits: 5),
      validator: (val) => AppValidators.quantity(val, min: 1, max: 10000),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildCostField() {
    return AppTextField(
      controller: draft.costController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: 'item_cost_price_label'.trParams({
        'symbol': AppConstants.getCurrencySymbol(currency).i18n(),
      }),
      prefixIcon: Icons.price_change_outlined,
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        return AppValidators.positiveAmount(val, allowZero: true);
      },
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildSellField({required bool isRequired}) {
    return AppTextField(
      controller: draft.sellController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: 'item_sell_price_label'.trParams({
        'symbol': AppConstants.getCurrencySymbol(currency).i18n(),
      }),
      hint: 'item_sell_price_hint'.i18n(),
      prefixIcon: Icons.sell_outlined,
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      validator: (val) {
        if (isRequired) {
          return AppValidators.positiveAmount(
            val,
            allowZero: false,
            customRequiredMsg: 'common_required'.i18n(),
          );
        }
        if (val == null || val.trim().isEmpty) return null;
        return AppValidators.positiveAmount(val, allowZero: true);
      },
      textInputAction: TextInputAction.next,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pfMode =
        isProductiveFamily ?? PreferencesService.instance.isProductiveFamilyMode;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'item_number_fmt'.trParams({'number': (index + 1).toString()}),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (canDelete)
                AppIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.statusDanger,
                  size: 32,
                  iconSize: 18,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: draft.nameController,
            label: 'item_name_label'.i18n(),
            prefixIcon: Icons.shopping_bag_outlined,
            inputFormatters: AppFormatters.generalText(maxLength: 80),
            validator: AppValidators.itemName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: _buildQtyField()),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: pfMode
                    ? _buildSellField(isRequired: true)
                    : _buildCostField(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          pfMode ? _buildCostField() : _buildSellField(isRequired: false),
          const SizedBox(height: 10),

          // قسم إرفاق الصور الموحد بنمط أبل مع خيارات الكاميرا والمعرض والمعاينة الفورية
          AppPhotoAttachmentSection(
            photos: draft.photos,
            compact: true,
            onPhotosChanged: (updatedList) {
              if (onPhotosChanged != null) {
                onPhotosChanged!(updatedList);
              } else {
                draft.photos
                  ..clear()
                  ..addAll(updatedList);
              }
            },
          ),
        ],
      ),
    );
  }
}
