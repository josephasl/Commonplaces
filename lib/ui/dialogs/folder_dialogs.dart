import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/attribute_selector.dart';
import '../widgets/delete_trigger_button.dart';
import 'confirm_dialog.dart';
import 'tag_dialogs.dart';

// --- PUBLIC WRAPPERS ---

Future<void> showAddFolderDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  return _showFolderDialog(
    context: context,
    storage: storage,
    onUpdate: onUpdate,
    folderToEdit: null,
  );
}

Future<void> showEditFolderDialog(
  BuildContext context,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  return _showFolderDialog(
    context: context,
    storage: storage,
    onUpdate: onUpdate,
    folderToEdit: folder,
  );
}

// --- UNIFIED DIALOG IMPLEMENTATION ---

Future<void> _showFolderDialog({
  required BuildContext context,
  required StorageService storage,
  required VoidCallback onUpdate,
  AppFolder? folderToEdit,
}) {
  final bool isEditMode = folderToEdit != null;

  final TextEditingController titleController = TextEditingController(
    text: isEditMode ? folderToEdit.getAttribute('title') : '',
  );

  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      List<String> availableTags = List.from(storage.getGlobalTags());
      List<String> selectedTags = isEditMode
          ? List.from(folderToEdit!.displayTags)
          : [];

      // Removed 'notes' from default defaults.
      List<String> visibleAttributes = isEditMode
          ? List.from(folderToEdit!.visibleAttributes)
          : ['title', 'tag'];

      final customAttrs = storage.getCustomAttributes();
      final allEntryAttrs = getEntryAttributes(customAttrs);

      return StatefulBuilder(
        builder: (context, setState) {
          void _onReorder(int oldIndex, int newIndex) {
            setState(() {
              final String item = availableTags.removeAt(oldIndex);
              availableTags.insert(newIndex, item);
            });
          }

          return BaseBottomSheet(
            title: isEditMode ? "Edit Folder" : "New Folder",
            onSave: () async {
              if (titleController.text.isNotEmpty) {
                final folder = isEditMode
                    ? folderToEdit!
                    : storage.createNewFolder();

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
                const Text(
                  "Folder Name",
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: titleController,
                  placeholder: "New folder",
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

                const SizedBox(height: 24),

                // --- HEADER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Filter by Tags",
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),

                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.add, size: 16),
                          SizedBox(width: 4),
                          Text(
                            "New Tag",
                            style: TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () async {
                        final newTag = await showAddTagDialog(
                          context,
                          storage,
                          onUpdate,
                        );

                        if (newTag != null && newTag.isNotEmpty) {
                          setState(() {
                            if (!availableTags.contains(newTag)) {
                              availableTags.add(newTag);
                            }
                            selectedTags.add(newTag);
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (availableTags.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "No tags available",
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          color: CupertinoColors.systemGrey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ReorderableWrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    padding: const EdgeInsets.all(0),
                    needsLongPressDraggable: true,
                    onReorder: _onReorder,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      final catColor = storage.getTagColor(tag);

                      return GestureDetector(
                        key: ValueKey(tag),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "#$tag",
                                style: TextStyle(
                                  fontFamily: '.SF Pro Text',
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.black,
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // --- Drag Handle Icon ---
                              Icon(
                                CupertinoIcons.bars,
                                size: 14,
                                color: isSelected
                                    ? Colors.black.withOpacity(0.5)
                                    : CupertinoColors.systemGrey2,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),
                const Text(
                  "Active Attributes",
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                AttributeSelector(
                  initialSelection: visibleAttributes,
                  availableAttributes: allEntryAttrs,
                  onChanged: (list) => visibleAttributes = list,
                ),

                if (isEditMode) ...[
                  const SizedBox(height: 24),
                  DeleteTriggerButton(
                    label: "Delete Folder",
                    onPressed: () {
                      Navigator.pop(context);
                      showDeleteConfirmationDialog(
                        context: context,
                        title: "Delete Folder?",
                        message:
                            "Delete '${folderToEdit!.getAttribute('title')}'?",
                        subtitle:
                            "This will delete the folder but NOT the entries inside it.",
                        onConfirm: () async {
                          await storage.deleteFolder(folderToEdit.id);
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
