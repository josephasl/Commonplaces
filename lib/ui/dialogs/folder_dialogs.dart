import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/attribute_selector.dart';
import '../widgets/delete_trigger_button.dart'; // Import
import 'confirm_dialog.dart';

// ... [showAddFolderDialog remains unchanged] ...
Future<void> showAddFolderDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final TextEditingController titleController = TextEditingController();
  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      List<String> selectedTags = [];
      List<String> visibleAttributes = ['title', 'tag', 'notes'];
      final customAttrs = storage.getCustomAttributes();
      final allEntryAttrs = getEntryAttributes(customAttrs);

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          return BaseBottomSheet(
            title: "New Folder",
            onSave: () async {
              if (titleController.text.isNotEmpty) {
                final newFolder = storage.createNewFolder();
                newFolder.setAttribute('title', titleController.text);
                newFolder.setAttribute('displayTags', selectedTags);
                newFolder.setAttribute('visibleAttributes', visibleAttributes);
                await storage.saveFolder(newFolder);
                onUpdate();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CupertinoTextField(
                  controller: titleController,
                  placeholder: "Folder Name",
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Filter by Tags",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                if (allTags.isEmpty)
                  const Center(
                    child: Text(
                      "No tags available",
                      style: TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      final catColor = storage.getTagColor(tag);
                      return GestureDetector(
                        onTap: () => setState(
                          () => isSelected
                              ? selectedTags.remove(tag)
                              : selectedTags.add(tag),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? catColor.withOpacity(0.2)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: catColor)
                                : null,
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.black : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 32),
                const Text(
                  "Visible Attributes",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 12),
                AttributeSelector(
                  initialSelection: visibleAttributes,
                  availableAttributes: allEntryAttrs,
                  onChanged: (list) => visibleAttributes = list,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ... [showEditFolderDialog UPDATED] ...
Future<void> showEditFolderDialog(
  BuildContext context,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final TextEditingController titleController = TextEditingController(
    text: folder.getAttribute('title'),
  );

  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      // ... [State setup] ...
      List<String> selectedTags = List.from(folder.displayTags);
      List<String> visibleAttributes = List.from(folder.visibleAttributes);
      final customAttrs = storage.getCustomAttributes();
      final allEntryAttrs = getEntryAttributes(customAttrs);

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          return BaseBottomSheet(
            title: "Edit Folder",
            onSave: () async {
              // ... [Save Logic] ...
              if (titleController.text.isNotEmpty) {
                folder.setAttribute('title', titleController.text);
                folder.setAttribute('displayTags', selectedTags);
                folder.setVisibleAttributes(visibleAttributes);
                await storage.saveFolder(folder);
                onUpdate();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... [TextFields & Tag Selectors & Attribute Selector] ...
                CupertinoTextField(
                  controller: titleController,
                  placeholder: "Folder Name",
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 24),
                // ... (Tags UI) ...
                // ... (Attribute UI) ...
                AttributeSelector(
                  initialSelection: visibleAttributes,
                  availableAttributes: allEntryAttrs,
                  onChanged: (list) => visibleAttributes = list,
                ),

                const SizedBox(height: 32),

                // --- UNIFIED DELETE BUTTON ---
                DeleteTriggerButton(
                  label: "Delete Folder",
                  onPressed: () {
                    Navigator.pop(context); // Close Edit Dialog
                    showDeleteConfirmationDialog(
                      context: context,
                      title: "Delete Folder?",
                      message: "Delete '${folder.getAttribute('title')}'?",
                      subtitle:
                          "This will delete the folder but NOT the entries inside it.",
                      onConfirm: () async {
                        await storage.deleteFolder(folder.id);
                        onUpdate();
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
