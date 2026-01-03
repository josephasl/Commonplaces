import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../app_styles.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import '../widgets/common_ui.dart';
import 'confirm_dialog.dart';

Future<String?> showAddTagDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  return _showTagDialog(
    context: context,
    storage: storage,
    onUpdate: onUpdate,
    tagToEdit: null,
  );
}

Future<void> showTagOptionsDialog(
  BuildContext context,
  StorageService storage,
  String tag,
  VoidCallback onUpdate,
) {
  return _showTagDialog(
    context: context,
    storage: storage,
    onUpdate: onUpdate,
    tagToEdit: tag,
  );
}

Future<String?> _showTagDialog({
  required BuildContext context,
  required StorageService storage,
  required VoidCallback onUpdate,
  String? tagToEdit,
}) {
  final bool isEditMode = tagToEdit != null;
  final controller = TextEditingController(text: isEditMode ? tagToEdit : '');
  String? selectedCategoryId;

  if (isEditMode) {
    final mapping = storage.getTagMapping();
    selectedCategoryId = mapping[tagToEdit];
  }

  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) {
      final categories = storage.getTagCategories();

      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> saveAndClose() async {
            if (controller.text.isNotEmpty) {
              final newName = controller.text;
              if (isEditMode) {
                if (newName != tagToEdit) {
                  await storage.renameGlobalTag(tagToEdit!, newName);
                }
                if (selectedCategoryId != null) {
                  await storage.setTagCategory(newName, selectedCategoryId!);
                }
              } else {
                await storage.addGlobalTag(newName);
                if (selectedCategoryId != null) {
                  await storage.setTagCategory(newName, selectedCategoryId!);
                }
              }
              onUpdate();
              if (ctx.mounted) Navigator.pop(ctx, newName);
            }
          }

          return BaseBottomSheet(
            title: isEditMode ? "Edit Stamp" : "New Stamp",
            onSave: saveAndClose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Name", style: AppTextStyles.label),
                const SizedBox(height: AppDimens.spacingS),
                CupertinoTextField(
                  controller: controller,
                  placeholder: "Enter name",
                  padding: const EdgeInsets.all(AppDimens.spacingM),
                  autofocus: !isEditMode,
                  decoration: AppDecorations.input,
                  style: AppTextStyles.body,
                  onSubmitted: (_) => saveAndClose(),
                ),
                const SizedBox(height: AppDimens.spacingL),
                const Text("Group", style: AppTextStyles.label),
                const SizedBox(height: AppDimens.spacingM),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => selectedCategoryId = null),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selectedCategoryId == null
                                ? AppColors.inputBackground
                                : AppColors.inputBackground,
                            borderRadius: BorderRadius.circular(
                              AppDimens.cornerRadius,
                            ),
                            border: selectedCategoryId == null
                                ? Border.all(
                                    color: AppColors.textSecondary,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Text(
                            "None",
                            style: AppTextStyles.body.copyWith(
                              fontWeight: selectedCategoryId == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selectedCategoryId == null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      ...categories.map((cat) {
                        final isSelected = selectedCategoryId == cat.id;
                        final catColor =
                            AppConstants.categoryColors[cat.colorIndex];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedCategoryId = cat.id),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color.lerp(Colors.white, catColor, 0.2)
                                  : AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(
                                AppDimens.cornerRadius,
                              ),
                              border: isSelected
                                  ? Border.all(color: catColor, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  AppConstants.categoryIcons[cat.iconIndex],
                                  size: 16,
                                  color: isSelected
                                      ? catColor
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.name,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                if (isEditMode) ...[
                  const SizedBox(height: AppDimens.spacingXL),
                  DeleteTriggerButton(
                    label: "Delete Tag",
                    onPressed: () {
                      Navigator.pop(ctx);
                      showDeleteConfirmationDialog(
                        context: context,
                        title: "Delete Tag?",
                        message: "Delete #$tagToEdit?",
                        subtitle: "It will be removed from all entries.",
                        onConfirm: () async {
                          await storage.removeGlobalTag(tagToEdit!);
                          onUpdate();
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> showAddCategoryDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final TextEditingController nameController = TextEditingController();
  int selectedColorIndex = 0;
  int selectedIconIndex = 0;

  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return BaseBottomSheet(
          title: "New Stamp Group",
          onSave: () async {
            if (nameController.text.isNotEmpty) {
              final newCat = TagCategory(
                id: const Uuid().v4(),
                name: nameController.text,
                colorIndex: selectedColorIndex,
                iconIndex: selectedIconIndex,
                sortOrder: 9999,
              );
              await storage.saveTagCategory(newCat);
              onUpdate();
              Navigator.pop(ctx);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Name", style: AppTextStyles.label),
              const SizedBox(height: AppDimens.spacingS),
              CupertinoTextField(
                controller: nameController,
                placeholder: "Enter group name",
                padding: const EdgeInsets.all(AppDimens.spacingM),
                autofocus: true,
                decoration: AppDecorations.input,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppDimens.spacingL),
              const Text("Color", style: AppTextStyles.label),
              const SizedBox(height: AppDimens.spacingM),
              AppColorPicker(
                selectedIndex: selectedColorIndex,
                onSelect: (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: AppDimens.spacingL),
              const Text("Icon", style: AppTextStyles.label),
              const SizedBox(height: AppDimens.spacingM),
              AppIconPicker(
                selectedIndex: selectedIconIndex,
                onSelect: (i) => setState(() => selectedIconIndex = i),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> showEditCategoryDialog(
  BuildContext context,
  StorageService storage,
  TagCategory category,
  VoidCallback onUpdate,
) {
  final TextEditingController nameController = TextEditingController(
    text: category.name,
  );
  int selectedColorIndex = category.colorIndex;
  int selectedIconIndex = category.iconIndex;

  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return BaseBottomSheet(
          title: "Edit Category",
          onSave: () async {
            if (nameController.text.isNotEmpty) {
              final updatedCat = TagCategory(
                id: category.id,
                name: nameController.text,
                colorIndex: selectedColorIndex,
                iconIndex: selectedIconIndex,
                sortOrder: category.sortOrder,
              );
              await storage.saveTagCategory(updatedCat);
              onUpdate();
              Navigator.pop(ctx);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Category Name", style: AppTextStyles.label),
              const SizedBox(height: AppDimens.spacingS),
              CupertinoTextField(
                controller: nameController,
                placeholder: "Enter category name",
                padding: const EdgeInsets.all(AppDimens.spacingM),
                decoration: AppDecorations.input,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppDimens.spacingL),
              const Text("Color", style: AppTextStyles.label),
              const SizedBox(height: AppDimens.spacingM),
              AppColorPicker(
                selectedIndex: selectedColorIndex,
                onSelect: (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: AppDimens.spacingL),
              const Text("Icon", style: AppTextStyles.label),
              const SizedBox(height: AppDimens.spacingM),
              AppIconPicker(
                selectedIndex: selectedIconIndex,
                onSelect: (i) => setState(() => selectedIconIndex = i),
              ),
              const SizedBox(height: AppDimens.spacingXL),
              DeleteTriggerButton(
                label: "Delete Category",
                onPressed: () {
                  Navigator.pop(ctx);
                  showDeleteConfirmationDialog(
                    context: context,
                    title: "Delete Category?",
                    message: "Delete '${category.name}'?",
                    subtitle: "Tags inside will become Uncategorized.",
                    onConfirm: () async {
                      await storage.deleteTagCategory(category.id);
                      onUpdate();
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
