import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';
import 'storage_service.dart';
import 'models.dart';
import 'attributes.dart';

// ... [AttributeSelector remains the same] ...
class AttributeSelector extends StatefulWidget {
  final List<String> initialSelection;
  final List<AttributeDefinition> availableAttributes;
  final Function(List<String>) onChanged;

  const AttributeSelector({
    super.key,
    required this.initialSelection,
    required this.availableAttributes,
    required this.onChanged,
  });

  @override
  State<AttributeSelector> createState() => _AttributeSelectorState();
}

class _AttributeSelectorState extends State<AttributeSelector> {
  late List<String> _orderedKeys;
  late Set<String> _checkedKeys;

  @override
  void initState() {
    super.initState();
    _checkedKeys = widget.initialSelection.toSet();
    _orderedKeys = List.from(widget.initialSelection);

    for (var attr in widget.availableAttributes) {
      if (!_orderedKeys.contains(attr.key)) {
        _orderedKeys.add(attr.key);
      }
    }
  }

  void _notifyParent() {
    final finalSelection = _orderedKeys
        .where((k) => _checkedKeys.contains(k))
        .toList();
    widget.onChanged(finalSelection);
  }

  @override
  Widget build(BuildContext context) {
    String getLabel(String key) {
      final def = widget.availableAttributes.firstWhere(
        (a) => a.key == key,
        orElse: () => AttributeDefinition(
          key: key,
          label: key,
          type: AttributeValueType.text,
          applyType: AttributeApplyType.entriesOnly,
        ),
      );
      return def.label;
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      header: const Padding(
        padding: EdgeInsets.only(bottom: 8.0, left: 4),
        child: Text(
          "Drag to reorder. Uncheck to hide.",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) newIndex -= 1;
          final item = _orderedKeys.removeAt(oldIndex);
          _orderedKeys.insert(newIndex, item);
        });
        _notifyParent();
      },
      children: _orderedKeys.map((key) {
        final isChecked = _checkedKeys.contains(key);

        return Material(
          key: ValueKey(key),
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: CupertinoColors.activeBlue,
            title: Text(
              getLabel(key),
              style: TextStyle(
                color: isChecked ? Colors.black : Colors.grey,
                fontWeight: isChecked ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            value: isChecked,
            secondary: const Icon(Icons.drag_handle, color: Colors.grey),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? val) {
              setState(() {
                if (val == true) {
                  _checkedKeys.add(key);
                } else {
                  _checkedKeys.remove(key);
                }
              });
              _notifyParent();
            },
          ),
        );
      }).toList(),
    );
  }
}

// ------------------------------------------
// SHARED UI BUILDER (Dynamic Height + Swipe Down)
// ------------------------------------------
Widget _buildBottomSheet({
  required BuildContext context,
  required String title,
  Widget? child,
  VoidCallback? onSave,
  bool hideSave = false,
}) {
  return Padding(
    // Push sheet up when keyboard opens
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      // Allow flexible height, but max out at 90% screen
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink to fit content
          children: [
            // Drag Handle (Optional visual cue)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  if (!hideSave)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: onSave,
                      child: const Text(
                        "Save",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    const SizedBox(width: 50),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey.shade200),
            Flexible(
              // Allows scrolling if content is too tall
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (child != null) child,
                    // --- NEW: Extra padding at bottom ---
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ... [The rest of the functions (showAddFolderDialog, showEditFolderDialog, etc.) just need to call _buildBottomSheet. They don't need changes themselves because _buildBottomSheet handles the structure.] ...

// 1. ADD FOLDER DIALOG
Future<void> showAddFolderDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final TextEditingController titleController = TextEditingController();
  return showCupertinoModalPopup(
    context: context,
    // Enable swipe-to-dismiss by setting barrierDismissible (default true) and semanticsDismissible (default true)
    // The key to smooth swiping is often ensuring the content isn't intercepting the drag at the very top.
    builder: (context) {
      List<String> selectedTags = [];
      List<String> visibleAttributes = ['title', 'tag', 'notes'];
      final customAttrs = storage.getCustomAttributes();
      final allEntryAttrs = getEntryAttributes(customAttrs);

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          return _buildBottomSheet(
            context: context,
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

// 2. EDIT FOLDER DIALOG
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
      List<String> selectedTags = List.from(folder.displayTags);
      List<String> visibleAttributes = List.from(folder.visibleAttributes);
      final customAttrs = storage.getCustomAttributes();
      final allEntryAttrs = getEntryAttributes(customAttrs);

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          return _buildBottomSheet(
            context: context,
            title: "Edit Folder",
            onSave: () async {
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
                  "Card Layout",
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

// 3. ADD ENTRY DIALOG
Future<void> showAddEntryDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate, {
  List<String>? prefillTags,
  List<String>? restrictToAttributes,
}) {
  final Map<String, dynamic> formValues = {};
  final Map<String, TextEditingController> textControllers = {};
  formValues['dateCompleted'] = DateTime.now().toIso8601String();
  formValues['tag'] = prefillTags != null
      ? List<String>.from(prefillTags)
      : <String>[];
  final customAttrs = storage.getCustomAttributes();
  final allAttributes = getEntryAttributes(customAttrs);
  List<AttributeDefinition> formAttributes;
  const hiddenKeys = ['dateCreated', 'dateEdited', 'lastAddedTo'];

  if (restrictToAttributes != null) {
    formAttributes = allAttributes.where((def) {
      if (hiddenKeys.contains(def.key)) return false;
      if (def.key == 'tag') return true;
      return restrictToAttributes.contains(def.key);
    }).toList();
  } else {
    formAttributes = allAttributes
        .where((def) => !hiddenKeys.contains(def.key))
        .toList();
  }

  for (var def in formAttributes) {
    if (def.key != 'tag' &&
        def.type != AttributeValueType.date &&
        !(def.type == AttributeValueType.number && def.key == 'starRating')) {
      textControllers[def.key] = TextEditingController(text: '');
    }
  }

  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      final TextEditingController tagSearchController = TextEditingController();
      String tagSearchQuery = '';
      Set<String> expandedKeys = {'title', 'tag', 'notes'};

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          final visibleTags = allTags
              .where(
                (tag) =>
                    tag.toLowerCase().contains(tagSearchQuery.toLowerCase()),
              )
              .toList();

          return _buildBottomSheet(
            context: context,
            title: "New Entry",
            onSave: () async {
              textControllers.forEach((key, controller) {
                formValues[key] = controller.text;
              });
              final newEntry = storage.createNewEntry();
              formValues.forEach((key, value) {
                newEntry.setAttribute(key, value);
              });
              await storage.saveEntry(newEntry);
              onUpdate();
              if (context.mounted) Navigator.pop(context);
            },
            child: Column(
              children: formAttributes.map((def) {
                return _buildFormSection(
                  def: def,
                  formValues: formValues,
                  textControllers: textControllers,
                  expandedKeys: expandedKeys,
                  storage: storage,
                  visibleTags: visibleTags,
                  tagSearchController: tagSearchController,
                  onTagQueryChanged: (val) =>
                      setState(() => tagSearchQuery = val),
                  onStateChange: () => setState(() {}),
                  context: context,
                );
              }).toList(),
            ),
          );
        },
      );
    },
  );
}

// 4. EDIT ENTRY DIALOG
Future<void> showEditEntryDialog(
  BuildContext context,
  AppEntry entry,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final Map<String, dynamic> formValues = Map.from(entry.attributes);
  final Map<String, TextEditingController> textControllers = {};
  final customAttrs = storage.getCustomAttributes();
  final allAttributes = getEntryAttributes(customAttrs);
  const hiddenKeys = ['dateCreated', 'dateEdited', 'lastAddedTo'];
  final formAttributes = allAttributes.where((def) {
    if (hiddenKeys.contains(def.key)) return false;
    return folder.visibleAttributes.contains(def.key) || def.key == 'tag';
  }).toList();

  for (var def in formAttributes) {
    if (def.key != 'tag' &&
        def.type != AttributeValueType.date &&
        !(def.type == AttributeValueType.number && def.key == 'starRating')) {
      textControllers[def.key] = TextEditingController(
        text: entry.getAttribute(def.key)?.toString() ?? '',
      );
    }
  }

  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      final TextEditingController tagSearchController = TextEditingController();
      String tagSearchQuery = '';
      Set<String> expandedKeys = {'title', 'tag', 'notes'};
      try {
        final rawList = storage.getExpandedEntryAttributes();
        expandedKeys = rawList.map((e) => e.toString()).toSet();
      } catch (_) {}

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          final visibleTags = allTags
              .where(
                (tag) =>
                    tag.toLowerCase().contains(tagSearchQuery.toLowerCase()),
              )
              .toList();

          return _buildBottomSheet(
            context: context,
            title: "Edit Entry",
            onSave: () async {
              textControllers.forEach((key, controller) {
                formValues[key] = controller.text;
              });
              formValues.forEach((key, value) {
                entry.setAttribute(key, value);
              });
              await storage.saveEntry(entry);
              onUpdate();
              Navigator.pop(context);
            },
            child: Column(
              children: [
                ...formAttributes.map((def) {
                  return _buildFormSection(
                    def: def,
                    formValues: formValues,
                    textControllers: textControllers,
                    expandedKeys: expandedKeys,
                    storage: storage,
                    visibleTags: visibleTags,
                    tagSearchController: tagSearchController,
                    onTagQueryChanged: (val) =>
                        setState(() => tagSearchQuery = val),
                    onStateChange: () {
                      setState(() {});
                      storage.saveExpandedAttributes(expandedKeys.toList());
                    },
                    context: context,
                  );
                }),
                const SizedBox(height: 32),
                CupertinoButton(
                  child: const Text(
                    "Delete Entry",
                    style: TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                  onPressed: () async {
                    final confirm = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text("Delete Entry?"),
                        content: const Text("This action cannot be undone."),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text("Cancel"),
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await storage.deleteEntry(entry.id);
                      Navigator.pop(context);
                      onUpdate();
                    }
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

// 5. ADD CUSTOM ATTRIBUTE DIALOG
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
        return _buildBottomSheet(
          context: context,
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

// 6. CATEGORY DIALOGS
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
        return _buildBottomSheet(
          context: context,
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
        return _buildBottomSheet(
          context: context,
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
              CupertinoTextField(
                controller: nameController,
                placeholder: "Category Name",
                padding: const EdgeInsets.all(12),
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

Future<void> showMoveTagDialog(
  BuildContext context,
  StorageService storage,
  String tag,
  VoidCallback onUpdate,
) {
  final categories = storage.getTagCategories();
  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => _buildBottomSheet(
      context: context,
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

// ------------------------------------------
// 5. HELPER: FORM SECTION BUILDER (STYLED)
// ------------------------------------------
Widget _buildFormSection({
  required BuildContext context,
  required AttributeDefinition def,
  required Map<String, dynamic> formValues,
  required Map<String, TextEditingController> textControllers,
  required Set<String> expandedKeys,
  required StorageService storage,
  required List<String> visibleTags,
  required TextEditingController tagSearchController,
  required Function(String) onTagQueryChanged,
  required VoidCallback onStateChange,
}) {
  /* ... same code as before ... */
  String subtitleText = "Not set";
  if (def.key == 'tag') {
    final tags = (formValues['tag'] as List?) ?? [];
    subtitleText = tags.isEmpty ? "No tags" : "${tags.length} selected";
  } else if (def.type == AttributeValueType.date) {
    final d = DateTime.tryParse(formValues[def.key]?.toString() ?? '');
    if (d != null) {
      subtitleText =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }
  } else if (def.type == AttributeValueType.number && def.key == 'starRating') {
    final num = formValues[def.key] ?? 0;
    subtitleText = "$num Stars";
  } else {
    final txt = formValues[def.key]?.toString();
    subtitleText = (txt == null || txt.isEmpty) ? "Empty" : txt;
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey(def.key),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: EdgeInsets.zero,
        title: Text(
          def.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitleText,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.systemGrey,
          ),
        ),
        initiallyExpanded: expandedKeys.contains(def.key),
        onExpansionChanged: (isOpen) {
          if (isOpen)
            expandedKeys.add(def.key);
          else
            expandedKeys.remove(def.key);
          onStateChange();
        },
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
        children: [
          if (def.key == 'tag') ...[
            CupertinoTextField(
              controller: tagSearchController,
              placeholder: "Filter tags...",
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              onChanged: onTagQueryChanged,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleTags.map((t) {
                final List<String> currentTags = List<String>.from(
                  formValues['tag'] ?? [],
                );
                final isSelected = currentTags.contains(t);
                final catColor = storage.getTagColor(t);
                return GestureDetector(
                  onTap: () {
                    isSelected ? currentTags.remove(t) : currentTags.add(t);
                    formValues['tag'] = currentTags;
                    onStateChange();
                  },
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
                      border: isSelected ? Border.all(color: catColor) : null,
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else if (def.type == AttributeValueType.date) ...[
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime:
                    DateTime.tryParse(formValues[def.key]?.toString() ?? '') ??
                    DateTime.now(),
                onDateTimeChanged: (picked) {
                  formValues[def.key] = picked.toIso8601String();
                  onStateChange();
                },
              ),
            ),
          ] else if (def.key == 'starRating') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final rating = (formValues[def.key] ?? 0) as int;
                return GestureDetector(
                  onTap: () {
                    formValues[def.key] = index + 1;
                    onStateChange();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      index < rating
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      color: CupertinoColors.systemYellow,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
          ] else ...[
            CupertinoTextField(
              controller: textControllers[def.key],
              placeholder: def.type == AttributeValueType.image
                  ? "Paste URL here"
                  : "Enter ${def.label}...",
              padding: const EdgeInsets.all(12),
              maxLines: def.key == 'notes' ? 4 : 1,
              keyboardType: def.type == AttributeValueType.number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              onChanged: (val) {
                formValues[def.key] = val;
                onStateChange();
              },
            ),
          ],
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
