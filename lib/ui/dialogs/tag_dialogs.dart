import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../app_styles.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
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
                const Text("Stamp Name", style: AppTextStyles.label),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: controller,
                  placeholder: "Enter name",
                  padding: const EdgeInsets.all(12),
                  autofocus: !isEditMode,
                  decoration: AppDecorations.input,
                  style: AppTextStyles.body,
                  onSubmitted: (_) => saveAndClose(),
                ),
                const SizedBox(height: 24),
                const Text("Group", style: AppTextStyles.label),
                const SizedBox(height: 12),
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
                                ? CupertinoColors.systemGrey4
                                : AppColors.inputBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: selectedCategoryId == null
                                ? Border.all(color: Colors.black54, width: 1.5)
                                : null,
                          ),
                          child: Text(
                            "None",
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: selectedCategoryId == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selectedCategoryId == null
                                  ? Colors.black
                                  : Colors.black54,
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
                                  ? catColor.withOpacity(0.2)
                                  : AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: catColor, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  AppConstants.categoryIcons[cat.iconIndex],
                                  size: 16,
                                  color: isSelected ? catColor : Colors.black54,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.name,
                                  style: AppTextStyles.bodySmall.copyWith(
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
                  const SizedBox(height: 32),
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
              const Text("Group name", style: AppTextStyles.label),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: nameController,
                placeholder: "Enter group name",
                padding: const EdgeInsets.all(12),
                autofocus: true,
                decoration: AppDecorations.input,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              const Text("Color", style: AppTextStyles.label),
              const SizedBox(height: 12),
              _buildColorPicker(
                selectedColorIndex,
                (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: 24),
              const Text("Icon", style: AppTextStyles.label),
              const SizedBox(height: 12),
              _buildIconPicker(
                selectedIconIndex,
                (i) => setState(() => selectedIconIndex = i),
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
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: nameController,
                placeholder: "Enter category name",
                padding: const EdgeInsets.all(12),
                decoration: AppDecorations.input,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              const Text("Color", style: AppTextStyles.label),
              const SizedBox(height: 12),
              _buildColorPicker(
                selectedColorIndex,
                (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: 24),
              const Text("Icon", style: AppTextStyles.label),
              const SizedBox(height: 12),
              _buildIconPicker(
                selectedIconIndex,
                (i) => setState(() => selectedIconIndex = i),
              ),
              const SizedBox(height: 32),
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

Widget _buildColorPicker(int selectedIndex, Function(int) onSelect) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(AppConstants.categoryColors.length, (index) {
        final isSelected = selectedIndex == index;
        return GestureDetector(
          onTap: () => onSelect(index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppConstants.categoryColors[index],
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.black, width: 3)
                  : null,
            ),
          ),
        );
      }),
    ),
  );
}

Widget _buildIconPicker(int selectedIndex, Function(int) onSelect) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(AppConstants.categoryIcons.length, (index) {
        final isSelected = selectedIndex == index;
        return GestureDetector(
          onTap: () => onSelect(index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.grey.shade300 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              AppConstants.categoryIcons[index],
              size: 24,
              color: Colors.black87,
            ),
          ),
        );
      }),
    ),
  );
}
