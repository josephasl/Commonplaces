import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart'; // Import
import 'confirm_dialog.dart'; // Import

// --- CATEGORY DIALOGS ---

// ... [showAddCategoryDialog remains unchanged] ...
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
          title: "New Category",
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
              CupertinoTextField(
                controller: nameController,
                placeholder: "Category Name",
                padding: const EdgeInsets.all(12),
                autofocus: true,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Color",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _buildColorPicker(
                selectedColorIndex,
                (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: 24),
              const Text(
                "Icon",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
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

// ... [showEditCategoryDialog UPDATED] ...
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
              const Text(
                "Name",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),

              CupertinoTextField(
                controller: nameController,
                placeholder: "Category Name",
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Color",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _buildColorPicker(
                selectedColorIndex,
                (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: 24),
              const Text(
                "Icon",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _buildIconPicker(
                selectedIconIndex,
                (i) => setState(() => selectedIconIndex = i),
              ),

              // --- UPDATED DELETE BUTTON ---
              const SizedBox(height: 24),
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

// ... [showAddTagDialog, showRenameTagDialog, showMoveTagDialog are unchanged except imports] ...
// I will include them for completeness so you can copy the file

Future<void> showAddTagDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final controller = TextEditingController();
  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => BaseBottomSheet(
      title: "New Tag",
      onSave: () async {
        if (controller.text.isNotEmpty) {
          await storage.addGlobalTag(controller.text);
          onUpdate();
          if (ctx.mounted) Navigator.pop(ctx);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Name",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: controller,
            placeholder: "Tag Name",
            padding: const EdgeInsets.all(12),
            autofocus: true,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            onSubmitted: (_) async {
              if (controller.text.isNotEmpty) {
                await storage.addGlobalTag(controller.text);
                onUpdate();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    ),
  );
}

// ... [showTagOptionsDialog UPDATED] ...
Future<void> showTagOptionsDialog(
  BuildContext context,
  StorageService storage,
  String tag,
  VoidCallback onUpdate,
) {
  final controller = TextEditingController(text: tag);

  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => BaseBottomSheet(
      title: "Edit Tag",
      onSave: () async {
        if (controller.text.isNotEmpty && controller.text != tag) {
          await storage.renameGlobalTag(tag, controller.text);
          onUpdate();
        }
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Name",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          // 1. Rename Field
          CupertinoTextField(
            controller: controller,
            placeholder: "Tag Name",
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            onSubmitted: (_) async {
              if (controller.text.isNotEmpty && controller.text != tag) {
                await storage.renameGlobalTag(tag, controller.text);
                onUpdate();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),

          const SizedBox(height: 12),

          // 2. Move to Category (Now a matching button)
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              // Light blue background to distinguish from Delete (Red)
              color: CupertinoColors.activeBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                Navigator.pop(ctx);
                showMoveTagDialog(context, storage, tag, onUpdate);
              },
              child: const Text(
                "Move to Category",
                style: TextStyle(
                  color: CupertinoColors.activeBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 3. Delete Tag
          DeleteTriggerButton(
            label: "Delete Tag",
            onPressed: () {
              Navigator.pop(ctx);
              showDeleteConfirmationDialog(
                context: context,
                title: "Delete Tag?",
                message: "Delete #$tag?",
                subtitle: "It will be removed from all entries.",
                onConfirm: () async {
                  await storage.removeGlobalTag(tag);
                  onUpdate();
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}
// ... [Helpers and MoveTagDialog remain same] ...

Future<void> showMoveTagDialog(
  BuildContext context,
  StorageService storage,
  String tag,
  VoidCallback onUpdate,
) {
  final categories = storage.getTagCategories();
  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => BaseBottomSheet(
      title: "Move Tag",
      hideSave: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              "Select a category for '#$tag'",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ...categories.map((cat) {
            return GestureDetector(
              onTap: () async {
                await storage.setTagCategory(tag, cat.id);
                onUpdate();
                Navigator.pop(ctx);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppConstants.categoryIcons[cat.iconIndex],
                      color: AppConstants.categoryColors[cat.colorIndex],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      cat.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      CupertinoIcons.right_chevron,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

Widget _buildOptionTile({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(
            CupertinoIcons.right_chevron,
            color: Colors.grey.shade400,
            size: 16,
          ),
        ],
      ),
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
