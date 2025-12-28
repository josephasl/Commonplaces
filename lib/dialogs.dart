import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // iOS Widgets
import 'package:uuid/uuid.dart'; // Ensure uuid is imported for categories
import 'storage_service.dart';
import 'models.dart';
import 'attributes.dart'; // Import registry

// ------------------------------------------
// HELPER WIDGET: Attribute Selector
// ------------------------------------------
class AttributeSelector extends StatefulWidget {
  final List<String> initialSelection;
  final Function(List<String>) onChanged;

  const AttributeSelector({
    super.key,
    required this.initialSelection,
    required this.onChanged,
  });

  @override
  State<AttributeSelector> createState() => _AttributeSelectorState();
}

class _AttributeSelectorState extends State<AttributeSelector> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    // Only show attributes relevant to entries
    final availableAttrs = getEntryAttributes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: availableAttrs.map((def) {
        // We use CheckboxListTile (Material) because Cupertino doesn't have a built-in equivalent
        // that handles the layout as nicely, but we wrap it to look clean.
        return Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            title: Text(def.label, style: const TextStyle(fontSize: 14)),
            value: _selected.contains(def.key),
            dense: true,
            activeColor: CupertinoColors.activeBlue,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  _selected.add(def.key);
                } else {
                  _selected.remove(def.key);
                }
                // Preserve generic order based on registry
                _selected.sort((a, b) {
                  final keys = attributeRegistry.keys.toList();
                  return keys.indexOf(a).compareTo(keys.indexOf(b));
                });
                widget.onChanged(_selected);
              });
            },
          ),
        );
      }).toList(),
    );
  }
}

// ------------------------------------------
// 1. ADD FOLDER DIALOG (Cupertino Style)
// ------------------------------------------
Future<void> showAddFolderDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final TextEditingController titleController = TextEditingController();

  return showCupertinoDialog(
    context: context,
    builder: (context) {
      List<String> selectedTags = [];
      // Default visible attributes
      List<String> visibleAttributes = ['title', 'tag', 'notes'];

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();

          return CupertinoAlertDialog(
            title: const Text("Create New Folder"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: titleController,
                    placeholder: "Folder Name",
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // TAG FILTER SECTION
                  const Text(
                    "Filter by Tags",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (allTags.isEmpty)
                    const Text(
                      "No tags available",
                      style: TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 12,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: allTags.map((tag) {
                        final isSelected = selectedTags.contains(tag);
                        final catColor = storage.getTagColor(
                          tag,
                        ); // Use category color

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              isSelected
                                  ? selectedTags.remove(tag)
                                  : selectedTags.add(tag);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? catColor.withOpacity(
                                      0.2,
                                    ) // Pastel selection
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
                                color: isSelected
                                    ? Colors
                                          .black // Or catColor.withOpacity(1.0)
                                    : CupertinoColors.black,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),

                  // ATTRIBUTE SELECTOR
                  const Text(
                    "Visible Attributes",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Select what to show on cards",
                    style: TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    height: 150, // Limit height for scrolling
                    child: SingleChildScrollView(
                      child: AttributeSelector(
                        initialSelection: visibleAttributes,
                        onChanged: (list) => visibleAttributes = list,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    final newFolder = storage.createNewFolder();
                    newFolder.setAttribute('title', titleController.text);
                    newFolder.setAttribute('displayTags', selectedTags);
                    newFolder.setAttribute(
                      'visibleAttributes',
                      visibleAttributes,
                    );

                    await storage.saveFolder(newFolder);
                    onUpdate();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      );
    },
  );
}

// ------------------------------------------
// 2. FOLDER SETTINGS DIALOG (Bottom Sheet Style)
// ------------------------------------------
Future<void> showFolderSettingsDialog(
  BuildContext context,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  // Use showCupertinoModalPopup for the "slide up from bottom" effect
  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      // Create a copy so we don't mutate until saved
      List<String> currentVisible = List.from(folder.visibleAttributes);

      return Container(
        // Height: 50% of screen or fitted to content
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 1. HEADER (Title + Done Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Spacer to balance the "Done" button so title is centered
                  const SizedBox(width: 48),

                  const Text(
                    "Visible Attributes",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                  ),

                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      "Done",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      folder.setVisibleAttributes(currentVisible);
                      await storage.saveFolder(folder);
                      onUpdate();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. ATTRIBUTE SELECTOR SCROLL AREA
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40), // Safety padding
                  child: AttributeSelector(
                    initialSelection: currentVisible,
                    onChanged: (list) => currentVisible = list,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------
// 3. ADD ENTRY DIALOG (Cupertino Modal Style)
// ------------------------------------------
Future<void> showAddEntryDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate, {
  List<String>? prefillTags,
  List<String>? restrictToAttributes,
}) {
  // 1. Initialize Data Containers
  final Map<String, dynamic> formValues = {};
  final Map<String, TextEditingController> textControllers = {};

  // 2. Default Values
  formValues['dateCompleted'] = DateTime.now().toIso8601String();

  // Use the list of tags passed in, or empty list
  formValues['tag'] = prefillTags != null
      ? List<String>.from(prefillTags)
      : <String>[];

  // 3. GET AND FILTER ATTRIBUTES
  final allAttributes = getEntryAttributes();
  List<AttributeDefinition> formAttributes;

  if (restrictToAttributes != null) {
    // FOLDER VIEW: Filter fields based on visible attributes
    formAttributes = allAttributes.where((def) {
      // Always exclude system fields
      if (def.isSystemField) return false;

      // Check if this attribute is in the restricted list
      bool isVisible = restrictToAttributes.contains(def.key);

      // CRITICAL: If we are pre-filling tags, we MUST include the 'tag' field
      // in the form definition so the controller/logic handles it,
      // even if the user hid the 'tag' pill on the card itself.
      if (def.key == 'tag' && (prefillTags?.isNotEmpty ?? false)) {
        return true;
      }

      return isVisible;
    }).toList();
  } else {
    // HOME VIEW: Show everything
    formAttributes = allAttributes.where((def) => !def.isSystemField).toList();
  }

  // 4. Initialize Controllers
  for (var def in formAttributes) {
    if (def.key != 'tag' &&
        def.type != AttributeValueType.date &&
        !(def.type == AttributeValueType.number && def.key == 'starRating')) {
      textControllers[def.key] = TextEditingController(text: '');
    }
  }

  // Use a Modal Popup for complex forms on iOS
  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      final TextEditingController tagSearchController = TextEditingController();
      String tagSearchQuery = '';

      Set<String> expandedKeys = {};
      try {
        final rawList = storage.getExpandedEntryAttributes();
        expandedKeys = rawList.map((e) => e.toString()).toSet();
      } catch (e) {
        expandedKeys = {'title', 'tag', 'dateCompleted'};
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          final visibleTags = allTags.where((tag) {
            return tag.toLowerCase().contains(tagSearchQuery.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 1. HEADER (Title + Buttons)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "New Entry",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          "Save",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          textControllers.forEach((key, controller) {
                            formValues[key] = controller.text;
                          });

                          final newEntry = storage.createNewEntry();
                          formValues.forEach((key, value) {
                            newEntry.setAttribute(key, value);
                          });

                          await storage.saveEntry(newEntry);

                          // Trigger the callback BEFORE closing?
                          // No, usually best to close then trigger, but for immediate UI feel:
                          onUpdate();

                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade200),

                // 2. FORM BODY
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      child: Column(
                        children: formAttributes.map((def) {
                          String subtitleText = "Not set";
                          if (def.key == 'tag') {
                            final tags = (formValues['tag'] as List?) ?? [];
                            subtitleText = tags.isEmpty
                                ? "No tags"
                                : "${tags.length} selected";
                          } else if (def.type == AttributeValueType.date) {
                            if (formValues[def.key] != null) {
                              final d = DateTime.tryParse(
                                formValues[def.key].toString(),
                              );
                              if (d != null) {
                                subtitleText =
                                    "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                              }
                            }
                          } else if (def.type == AttributeValueType.number) {
                            final num = formValues[def.key];
                            subtitleText = num != null
                                ? "$num Stars"
                                : "No rating";
                          } else {
                            final txt = formValues[def.key]?.toString();
                            subtitleText = (txt == null || txt.isEmpty)
                                ? "Empty"
                                : txt;
                          }

                          return ExpansionTile(
                            key: ValueKey(def.key),
                            title: Text(
                              def.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            childrenPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            initiallyExpanded: expandedKeys.contains(def.key),
                            onExpansionChanged: (isOpen) {
                              if (isOpen)
                                expandedKeys.add(def.key);
                              else
                                expandedKeys.remove(def.key);
                              try {
                                storage.saveExpandedAttributes(
                                  expandedKeys.toList(),
                                );
                              } catch (_) {}
                            },
                            children: [
                              if (def.key == 'tag') ...[
                                CupertinoTextField(
                                  controller: tagSearchController,
                                  placeholder: "Filter tags...",
                                  prefix: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      CupertinoIcons.search,
                                      size: 18,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onChanged: (val) =>
                                      setState(() => tagSearchQuery = val),
                                ),
                                const SizedBox(height: 12),
                                if (allTags.isEmpty)
                                  const Text(
                                    "No tags created.",
                                    style: TextStyle(
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: visibleTags.map((t) {
                                      final rawList =
                                          formValues['tag'] as List? ?? [];
                                      final List<String> currentTags = rawList
                                          .map((e) => e.toString())
                                          .toList();
                                      final isSelected = currentTags.contains(
                                        t,
                                      );
                                      final catColor = storage.getTagColor(t);

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            isSelected
                                                ? currentTags.remove(t)
                                                : currentTags.add(t);
                                            formValues['tag'] = currentTags;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? catColor.withOpacity(
                                                    0.2,
                                                  ) // Pastel
                                                : CupertinoColors.systemGrey6,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: isSelected
                                                ? Border.all(color: catColor)
                                                : null,
                                          ),
                                          child: Text(
                                            t,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isSelected
                                                  ? Colors.black
                                                  : Colors.black,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ] else if (def.type ==
                                  AttributeValueType.date) ...[
                                SizedBox(
                                  height: 200,
                                  child: CupertinoDatePicker(
                                    mode: CupertinoDatePickerMode.date,
                                    initialDateTime:
                                        DateTime.tryParse(
                                          formValues[def.key].toString(),
                                        ) ??
                                        DateTime.now(),
                                    onDateTimeChanged: (picked) {
                                      setState(
                                        () => formValues[def.key] = picked
                                            .toIso8601String(),
                                      );
                                    },
                                  ),
                                ),
                              ] else if (def.type ==
                                      AttributeValueType.number &&
                                  def.key == 'starRating') ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    final rating =
                                        (formValues[def.key] ?? 0) as int;
                                    return GestureDetector(
                                      onTap: () => setState(
                                        () => formValues[def.key] = index + 1,
                                      ),
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
                                  placeholder:
                                      def.type == AttributeValueType.image
                                      ? "Paste URL here"
                                      : "Enter ${def.label}...",
                                  padding: const EdgeInsets.all(12),
                                  maxLines: def.key == 'notes' ? 3 : 1,
                                  onChanged: (val) {
                                    formValues[def.key] = val;
                                    setState(() {});
                                  },
                                ),
                              ],
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ------------------------------------------
// 4. ADD CATEGORY DIALOG
// ------------------------------------------
Future<void> showAddCategoryDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate,
) {
  // ... [Logic remains same as before, see showEditCategoryDialog below for the pattern] ...
  final TextEditingController nameController = TextEditingController();
  int selectedColorIndex = 0;
  int selectedIconIndex = 0;

  return showCupertinoDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return CupertinoAlertDialog(
          title: const Text("New Category"),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                placeholder: "Category Name",
              ),
              const SizedBox(height: 16),
              _buildColorPicker(
                selectedColorIndex,
                (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: 16),
              _buildIconPicker(
                selectedIconIndex,
                (i) => setState(() => selectedIconIndex = i),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              child: const Text("Create"),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final newCat = TagCategory(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    colorIndex: selectedColorIndex,
                    iconIndex: selectedIconIndex,
                  );
                  await storage.saveTagCategory(newCat);
                  onUpdate();
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

// ------------------------------------------
// 5. EDIT CATEGORY DIALOG (NEW)
// ------------------------------------------
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

  return showCupertinoDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return CupertinoAlertDialog(
          title: const Text("Edit Category"),
          content: Column(
            children: [
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: nameController,
                placeholder: "Category Name",
              ),
              const SizedBox(height: 16),
              _buildColorPicker(
                selectedColorIndex,
                (i) => setState(() => selectedColorIndex = i),
              ),
              const SizedBox(height: 16),
              _buildIconPicker(
                selectedIconIndex,
                (i) => setState(() => selectedIconIndex = i),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              child: const Text("Save"),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  // Create updated object with SAME ID
                  final updatedCat = TagCategory(
                    id: category.id,
                    name: nameController.text,
                    colorIndex: selectedColorIndex,
                    iconIndex: selectedIconIndex,
                  );
                  await storage.saveTagCategory(updatedCat);
                  onUpdate();
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

// --- Helper Widgets to reduce code duplication ---
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppConstants.categoryColors[index],
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.black, width: 2)
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
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? Colors.grey.shade300 : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              AppConstants.categoryIcons[index],
              size: 20,
              color: Colors.black87,
            ),
          ),
        );
      }),
    ),
  );
}

// ------------------------------------------
// 6. MOVE TAG DIALOG
// ------------------------------------------
Future<void> showMoveTagDialog(
  BuildContext context,
  StorageService storage,
  String tag,
  VoidCallback onUpdate,
) {
  final categories = storage.getTagCategories();

  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text("Move '$tag' to Category"),
      actions: categories.map((cat) {
        return CupertinoActionSheetAction(
          onPressed: () async {
            await storage.setTagCategory(tag, cat.id);
            onUpdate();
            Navigator.pop(ctx);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppConstants.categoryIcons[cat.iconIndex],
                color: AppConstants.categoryColors[cat.colorIndex],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(cat.name, style: const TextStyle(color: Colors.black)),
            ],
          ),
        );
      }).toList(),
      cancelButton: CupertinoActionSheetAction(
        child: const Text("Cancel"),
        onPressed: () => Navigator.pop(ctx),
      ),
    ),
  );
}

Future<void> showEditFolderDialog(
  BuildContext context,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  final TextEditingController titleController = TextEditingController(
    text: folder.getAttribute('title'),
  );

  return showCupertinoDialog(
    context: context,
    builder: (context) {
      // Start with currently selected tags
      List<String> selectedTags = List.from(folder.displayTags);

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();

          return CupertinoAlertDialog(
            title: const Text("Edit Folder"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: titleController,
                    placeholder: "Folder Name",
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Filter by Tags",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      final catColor = storage.getTagColor(tag);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            isSelected
                                ? selectedTags.remove(tag)
                                : selectedTags.add(tag);
                          });
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
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    folder.setAttribute('title', titleController.text);
                    folder.setAttribute('displayTags', selectedTags);

                    await storage.saveFolder(folder);
                    onUpdate();
                    Navigator.pop(context);
                  }
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      );
    },
  );
}

// ------------------------------------------
// 4. EDIT ENTRY DIALOG (Full Implementation)
// ------------------------------------------
Future<void> showEditEntryDialog(
  BuildContext context,
  AppEntry entry,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  // 1. Initialize local state with entry's existing data
  final Map<String, dynamic> formValues = Map.from(entry.attributes);
  final Map<String, TextEditingController> textControllers = {};

  final allAttributes = getEntryAttributes();
  // Filter fields based on folder visible attributes or system requirement (tags)
  final formAttributes = allAttributes.where((def) {
    if (def.isSystemField) return false;
    return folder.visibleAttributes.contains(def.key) || def.key == 'tag';
  }).toList();

  // 2. Initialize Controllers for Text/Image fields
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

      // Manage expansion states
      Set<String> expandedKeys = {};
      try {
        final rawList = storage.getExpandedEntryAttributes();
        expandedKeys = rawList.map((e) => e.toString()).toSet();
      } catch (e) {
        expandedKeys = {'title', 'tag', 'dateCompleted'};
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          final visibleTags = allTags.where((tag) {
            return tag.toLowerCase().contains(tagSearchQuery.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "Edit Entry",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      CupertinoButton(
                        child: const Text(
                          "Save",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          // Sync text controllers back to formValues
                          textControllers.forEach((key, controller) {
                            formValues[key] = controller.text;
                          });

                          // Update entry object
                          formValues.forEach((key, value) {
                            entry.setAttribute(key, value);
                          });

                          await storage.saveEntry(entry);
                          onUpdate();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // FORM BODY
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                          ...formAttributes.map((def) {
                            // Determine subtitle display text
                            String subtitleText = "Not set";
                            if (def.key == 'tag') {
                              final tags = (formValues['tag'] as List?) ?? [];
                              subtitleText = tags.isEmpty
                                  ? "No tags"
                                  : "${tags.length} selected";
                            } else if (def.type == AttributeValueType.date) {
                              final d = DateTime.tryParse(
                                formValues[def.key]?.toString() ?? '',
                              );
                              if (d != null) {
                                subtitleText =
                                    "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                              }
                            } else if (def.type == AttributeValueType.number) {
                              final num = formValues[def.key] ?? 0;
                              subtitleText = "$num Stars";
                            } else {
                              final txt = formValues[def.key]?.toString();
                              subtitleText = (txt == null || txt.isEmpty)
                                  ? "Empty"
                                  : txt;
                            }

                            return ExpansionTile(
                              key: ValueKey(def.key),
                              title: Text(
                                def.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
                                storage.saveExpandedAttributes(
                                  expandedKeys.toList(),
                                );
                              },
                              childrenPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              children: [
                                // TAG EDITOR
                                if (def.key == 'tag') ...[
                                  CupertinoTextField(
                                    controller: tagSearchController,
                                    placeholder: "Filter tags...",
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey6,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    onChanged: (val) =>
                                        setState(() => tagSearchQuery = val),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: visibleTags.map((t) {
                                      final List<String> currentTags =
                                          List<String>.from(
                                            formValues['tag'] ?? [],
                                          );
                                      final isSelected = currentTags.contains(
                                        t,
                                      );
                                      final catColor = storage.getTagColor(t);
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            isSelected
                                                ? currentTags.remove(t)
                                                : currentTags.add(t);
                                            formValues['tag'] = currentTags;
                                          });
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: isSelected
                                                ? Border.all(color: catColor)
                                                : null,
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
                                ]
                                // DATE EDITOR
                                else if (def.type ==
                                    AttributeValueType.date) ...[
                                  SizedBox(
                                    height: 200,
                                    child: CupertinoDatePicker(
                                      mode: CupertinoDatePickerMode.date,
                                      initialDateTime:
                                          DateTime.tryParse(
                                            formValues[def.key]?.toString() ??
                                                '',
                                          ) ??
                                          DateTime.now(),
                                      onDateTimeChanged: (picked) => setState(
                                        () => formValues[def.key] = picked
                                            .toIso8601String(),
                                      ),
                                    ),
                                  ),
                                ]
                                // RATING EDITOR
                                else if (def.key == 'starRating') ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (index) {
                                      final rating =
                                          (formValues[def.key] ?? 0) as int;
                                      return GestureDetector(
                                        onTap: () => setState(
                                          () => formValues[def.key] = index + 1,
                                        ),
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
                                ]
                                // TEXT/IMAGE EDITOR
                                else ...[
                                  CupertinoTextField(
                                    controller: textControllers[def.key],
                                    placeholder:
                                        def.type == AttributeValueType.image
                                        ? "Paste URL here"
                                        : "Enter ${def.label}...",
                                    padding: const EdgeInsets.all(12),
                                    maxLines: def.key == 'notes' ? 4 : 1,
                                    onChanged: (val) => setState(
                                      () => formValues[def.key] = val,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }).toList(),

                          const SizedBox(height: 32),
                          // Destructive Delete Button
                          CupertinoButton(
                            child: const Text(
                              "Delete Entry",
                              style: TextStyle(
                                color: CupertinoColors.destructiveRed,
                              ),
                            ),
                            onPressed: () async {
                              final confirm = await showCupertinoDialog<bool>(
                                context: context,
                                builder: (ctx) => CupertinoAlertDialog(
                                  title: const Text("Delete Entry?"),
                                  content: const Text(
                                    "This action cannot be undone.",
                                  ),
                                  actions: [
                                    CupertinoDialogAction(
                                      child: const Text("Cancel"),
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
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
                                Navigator.pop(context); // Close Edit Dialog
                                onUpdate(); // This will trigger the pop in EntryScreen
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
