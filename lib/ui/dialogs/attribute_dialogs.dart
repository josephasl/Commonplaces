import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../storage_service.dart';
import '../../attributes.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import 'confirm_dialog.dart';

// --- ADD ATTRIBUTE (Unchanged) ---
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
              CupertinoTextField(
                controller: labelController,
                placeholder: "Field Name (e.g. Author)",
                padding: const EdgeInsets.all(12),
                autofocus: true,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Field Type",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
                    AttributeValueType.text: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text("Text"),
                    ),
                    AttributeValueType.number: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text("Num"),
                    ),
                    AttributeValueType.date: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text("Date"),
                    ),
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

// --- MANAGE ATTRIBUTE (Updated to match Tag Options) ---
Future<void> showAttributeOptionsDialog(
  BuildContext context,
  StorageService storage,
  AttributeDefinition attribute,
  VoidCallback onUpdate,
) {
  // 1. Initialize controller with current name
  final controller = TextEditingController(text: attribute.label);

  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => BaseBottomSheet(
      title: "Edit Attribute",
      // 2. Handle Rename on Save
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
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 12),
          // 3. Rename Input Field
          CupertinoTextField(
            controller: controller,
            placeholder: "Attribute Name",
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
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

          const SizedBox(height: 24),

          // 4. Unified Delete Button
          DeleteTriggerButton(
            label: "Delete Attribute",
            onPressed: () {
              Navigator.pop(ctx); // Close options first
              showDeleteConfirmationDialog(
                context: context,
                title: "Delete Attribute?",
                message: "Delete '${attribute.label}'?",
                subtitle: "This will remove this data field from all entries.",
                onConfirm: () async {
                  await storage.deleteCustomAttribute(attribute.key);
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
