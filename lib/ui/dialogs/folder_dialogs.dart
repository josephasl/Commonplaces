import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart'; // Assuming this is unused based on usage of ReorderableListView.builder
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../widgets/base_bottom_sheet.dart';
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
      // 1. Setup Tags
      List<String> availableTags = List.from(storage.getGlobalTags());
      List<String> selectedTags = isEditMode
          ? List.from(folderToEdit!.displayTags)
          : [];

      // 2. Setup Attributes with Default Sort Order
      final allDefinitions = storage.getSortedAttributeDefinitions();

      // Initialize the toggle states locally
      final Set<String> activeSet = isEditMode
          ? Set.from(folderToEdit!.activeAttributes)
          : {'tag'};

      final Set<String> visibleSet = isEditMode
          ? Set.from(folderToEdit!.visibleAttributes)
          : {'tag'};

      // 3. Initialize Sorting Order for THIS specific folder
      List<AttributeDefinition> sortedAttributes = List.from(allDefinitions);

      if (isEditMode && folderToEdit!.activeAttributes.isNotEmpty) {
        final orderMap = {
          for (var i = 0; i < folderToEdit!.activeAttributes.length; i++)
            folderToEdit!.activeAttributes[i]: i,
        };

        sortedAttributes.sort((a, b) {
          final indexA = orderMap[a.key] ?? 9999;
          final indexB = orderMap[b.key] ?? 9999;
          return indexA.compareTo(indexB);
        });
      }

      return StatefulBuilder(
        builder: (context, setState) {
          void _onTagReorder(int oldIndex, int newIndex) {
            setState(() {
              final String item = availableTags.removeAt(oldIndex);
              availableTags.insert(newIndex, item);
            });
          }

          void _onAttrReorder(int oldIndex, int newIndex) {
            setState(() {
              if (oldIndex < newIndex) newIndex -= 1;
              final item = sortedAttributes.removeAt(oldIndex);
              sortedAttributes.insert(newIndex, item);
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

                // Reconstruct lists based on the NEW visual order
                List<String> newActiveList = [];
                List<String> newVisibleList = [];

                for (var def in sortedAttributes) {
                  if (activeSet.contains(def.key)) {
                    newActiveList.add(def.key);
                  }
                  if (visibleSet.contains(def.key)) {
                    newVisibleList.add(def.key);
                  }
                }

                folder.setActiveAttributes(newActiveList);
                folder.setVisibleAttributes(newVisibleList);

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

                // --- TAGS SECTION ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
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
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 0,
                      child: const Text(
                        "New Tag",
                        style: TextStyle(fontSize: 14),
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
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "No tags available",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ReorderableWrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    padding: EdgeInsets.zero,
                    needsLongPressDraggable: true,
                    onReorder: _onTagReorder,
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
                          child: Text(
                            "#$tag",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),

                // --- ATTRIBUTES HEADER ---
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Attributes",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // --- REORDERABLE ATTRIBUTE LIST ---
                // FIX: Removed outer Container color.
                // Using ReorderableListView directly with custom item styling.
                SizedBox(
                  height: 300, // Constrain height inside bottom sheet
                  child: Theme(
                    data: ThemeData(
                      canvasColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: ReorderableListView.builder(
                      physics:
                          const ClampingScrollPhysics(), // Scrollable if list is long
                      itemCount: sortedAttributes.length,
                      onReorder: _onAttrReorder,
                      // FIX: Added Proxy Decorator for drag effect
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 4,
                          color: Colors.transparent,
                          shadowColor: Colors.black26,
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final def = sortedAttributes[index];
                        final attrKey = def.key;

                        final isActive = activeSet.contains(attrKey);
                        final isVisible = visibleSet.contains(attrKey);
                        final isMandatory = attrKey == 'tag';
                        final isLast = index == sortedAttributes.length - 1;

                        return Container(
                          key: ValueKey(attrKey),
                          // FIX: Added white background and rounded corners logic
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: index == 0
                                  ? const Radius.circular(10)
                                  : Radius.zero,
                              bottom: isLast
                                  ? const Radius.circular(10)
                                  : Radius.zero,
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8, // Increased padding
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    // 1. BURGER (Drag Handle) - LEFT
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.only(
                                          left: 4,
                                          right: 12,
                                        ),
                                        child: Icon(
                                          Icons.menu,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                    ),

                                    // 2. ATTRIBUTE NAME - CENTER
                                    Expanded(
                                      child: Text(
                                        def.label,
                                        style: TextStyle(
                                          fontSize: 14, // Matched font size
                                          color: isActive
                                              ? Colors.black
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),

                                    // 3. SQUARE TICKBOX (Active) - RIGHT
                                    CupertinoCheckbox(
                                      value: isActive,
                                      activeColor: CupertinoColors.activeBlue,
                                      onChanged: isMandatory
                                          ? null
                                          : (val) {
                                              setState(() {
                                                if (val == true) {
                                                  activeSet.add(attrKey);
                                                  visibleSet.add(attrKey);
                                                } else {
                                                  activeSet.remove(attrKey);
                                                  visibleSet.remove(attrKey);
                                                }
                                              });
                                            },
                                    ),

                                    const SizedBox(width: 4),

                                    // 4. EYE ICON (Visible) - RIGHT
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: (!isActive)
                                          ? null
                                          : () {
                                              setState(() {
                                                if (isVisible) {
                                                  visibleSet.remove(attrKey);
                                                } else {
                                                  visibleSet.add(attrKey);
                                                }
                                              });
                                            },
                                      child: Icon(
                                        isVisible
                                            ? CupertinoIcons.eye_solid
                                            : CupertinoIcons.eye_slash,
                                        color: isActive
                                            ? (isVisible
                                                  ? CupertinoColors.activeBlue
                                                  : Colors.grey)
                                            : Colors.grey.withOpacity(0.3),
                                        size: 20,
                                      ),
                                    ),

                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ),
                              // FIX: Added Divider logic
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 44, // Align with text start
                                  color: Color(0xFFF0F0F0),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
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
