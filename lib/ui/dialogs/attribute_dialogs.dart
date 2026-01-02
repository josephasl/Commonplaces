import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../storage_service.dart';
import '../../attributes.dart';
import '../app_styles.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import 'confirm_dialog.dart';

Future<void> showAddAttributeDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final TextEditingController labelController = TextEditingController();
  AttributeValueType selectedType = AttributeValueType.text;

  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return BaseBottomSheet(
          title: "New Attribute",
          onSave: () async {
            if (labelController.text.isNotEmpty) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final safeLabel = labelController.text
                  .trim()
                  .replaceAll(RegExp(r'\s+'), '_')
                  .toLowerCase();
              final key = "${safeLabel}_$timestamp";
              final newAttr = AttributeDefinition(
                key: key,
                label: labelController.text,
                type: selectedType,
                applyType: AttributeApplyType.entriesOnly,
              );
              await storage.addCustomAttribute(newAttr);
              onUpdate();
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Name", style: AppTextStyles.label),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: labelController,
                placeholder: "New name",
                padding: const EdgeInsets.all(12),
                autofocus: true,
                decoration: AppDecorations.input,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              const Text("Type", style: AppTextStyles.label),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeOption(
                      "Text",
                      CupertinoIcons.text_alignleft,
                      AttributeValueType.text,
                      selectedType,
                      (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      "Number",
                      CupertinoIcons.number,
                      AttributeValueType.number,
                      selectedType,
                      (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      "Image",
                      CupertinoIcons.photo,
                      AttributeValueType.image,
                      selectedType,
                      (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      "Date",
                      CupertinoIcons.calendar,
                      AttributeValueType.date,
                      selectedType,
                      (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      "Rating",
                      CupertinoIcons.star_fill,
                      AttributeValueType.rating,
                      selectedType,
                      (t) => setState(() => selectedType = t),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _buildTypeOption(
  String label,
  IconData icon,
  AttributeValueType type,
  AttributeValueType selected,
  Function(AttributeValueType) onTap,
) {
  final isSelected = type == selected;
  return GestureDetector(
    onTap: () => onTap(type),
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? CupertinoColors.systemGrey5 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: Colors.black12) : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.black : Colors.black54,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: isSelected ? Colors.black : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAttributeOptionsDialog(
  BuildContext context,
  StorageService storage,
  AttributeDefinition attribute,
  VoidCallback onUpdate,
) {
  final controller = TextEditingController(text: attribute.label);

  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => BaseBottomSheet(
      title: "Edit Attribute",
      onSave: () async {
        if (controller.text.isNotEmpty && controller.text != attribute.label) {
          final updatedAttr = AttributeDefinition(
            key: attribute.key,
            label: controller.text,
            type: attribute.type,
            applyType: attribute.applyType,
            isSystemField: attribute.isSystemField,
          );
          await storage.updateCustomAttribute(updatedAttr);
          onUpdate();
        }
        if (ctx.mounted) Navigator.pop(ctx);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Name", style: AppTextStyles.label),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: controller,
            placeholder: "Attribute Name",
            padding: const EdgeInsets.all(12),
            decoration: AppDecorations.input,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 32),
          DeleteTriggerButton(
            label: "Delete Attribute",
            onPressed: () {
              Navigator.pop(ctx);
              showDeleteConfirmationDialog(
                context: context,
                title: "Delete Attribute?",
                message: "Delete '${attribute.label}'?",
                subtitle: "This will remove this data field from all entries.",
                onConfirm: () async {
                  await storage.deleteCustomAttribute(attribute.key);
                  final allFolders = storage.getAllFolders();
                  for (var folder in allFolders) {
                    bool changed = false;
                    List<String> visible = List.from(folder.visibleAttributes);
                    List<String> active = List.from(folder.activeAttributes);
                    if (visible.contains(attribute.key)) {
                      visible.remove(attribute.key);
                      changed = true;
                    }
                    if (active.contains(attribute.key)) {
                      active.remove(attribute.key);
                      changed = true;
                    }
                    if (changed) {
                      folder.setVisibleAttributes(visible);
                      folder.setActiveAttributes(active);
                      await storage.saveFolder(folder);
                    }
                  }
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
