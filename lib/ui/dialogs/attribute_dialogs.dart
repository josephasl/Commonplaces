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
              if (ctx.mounted) Navigator.pop(ctx);
            }
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
                controller: labelController,
                placeholder: "New name",
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
                "Type",
                style: TextStyle(
                  fontFamily: '.SF Pro Text',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),

              // --- UPDATED: Horizontal Scroll Row (Matching Tag/Category Dialog Style) ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeOption(
                      label: "Text",
                      icon: CupertinoIcons.text_alignleft,
                      type: AttributeValueType.text,
                      selected: selectedType,
                      onTap: (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      label: "Number",
                      icon: CupertinoIcons.number,
                      type: AttributeValueType.number,
                      selected: selectedType,
                      onTap: (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      label: "Image",
                      icon: CupertinoIcons.photo,
                      type: AttributeValueType.image,
                      selected: selectedType,
                      onTap: (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      label: "Date",
                      icon: CupertinoIcons.calendar,
                      type: AttributeValueType.date,
                      selected: selectedType,
                      onTap: (t) => setState(() => selectedType = t),
                    ),
                    _buildTypeOption(
                      label: "Rating",
                      icon: CupertinoIcons.star_fill,
                      type: AttributeValueType.rating,
                      selected: selectedType,
                      onTap: (t) => setState(() => selectedType = t),
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

// --- HELPER WIDGET FOR SELECTION (Matching Tag Dialog Style) ---
Widget _buildTypeOption({
  required String label,
  required IconData icon,
  required AttributeValueType type,
  required AttributeValueType selected,
  required Function(AttributeValueType) onTap,
}) {
  final isSelected = type == selected;
  return GestureDetector(
    onTap: () => onTap(type),
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? CupertinoColors.systemGrey5
            : Colors
                  .transparent, // Like the 'Group' chooser in Tag Dialog (unselected transparent)
        borderRadius: BorderRadius.circular(12),
        // Optional: Add border if you want it exactly like the "None" button,
        // but often categories in that dialog just use background color.
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
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 14,
              color: isSelected ? Colors.black : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
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

                  // Cleanup Folders (remove deleted key from active/visible lists)
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
