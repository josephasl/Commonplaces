import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../storage_service.dart';
import '../../attributes.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import 'confirm_dialog.dart';

// --- ADD ATTRIBUTE ---
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
              Navigator.pop(ctx);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Field Name",
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: labelController,
                placeholder: "e.g. My Rating, Released, Notes",
                padding: const EdgeInsets.all(12),
                autofocus: true,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                style: const TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Field Type",
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<AttributeValueType>(
                  groupValue: selectedType,
                  onValueChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                  children: const {
                    AttributeValueType.text: Text("Text"),
                    AttributeValueType.number: Text("Num"),
                    AttributeValueType.date: Text("Date"),
                    AttributeValueType.rating: Text("Rate"),
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// --- MANAGE ATTRIBUTE ---
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
          const Text(
            "Name",
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: controller,
            placeholder: "Attribute Name",
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            style: const TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 16,
              color: Colors.black,
            ),
            onSubmitted: (_) async {
              if (controller.text.isNotEmpty &&
                  controller.text != attribute.label) {
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
                  // Clean up folders that reference this attribute
                  final allFolders = storage.getAllFolders();
                  for (var folder in allFolders) {
                    if (folder.visibleAttributes.contains(attribute.key)) {
                      final updatedAttrs = List<String>.from(
                        folder.visibleAttributes,
                      )..remove(attribute.key);
                      folder.setVisibleAttributes(updatedAttrs);
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
