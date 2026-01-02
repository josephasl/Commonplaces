import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import 'confirm_dialog.dart';

// --- PUBLIC WRAPPERS ---

Future<void> showAddEntryDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate, {
  List<String>? prefillTags,
  AppFolder? folderContext, // NEW: Context to know which order to use
}) {
  // If we are in a folder, use its active attributes (which respect its sort order)
  // If from Home (folderContext is null), use the Master Sort Order from storage
  List<String>? attributeOrder;

  if (folderContext != null) {
    attributeOrder = folderContext.activeAttributes;
  } else {
    // Fetch master order from storage logic
    attributeOrder = storage
        .getSortedAttributeDefinitions()
        .map((a) => a.key)
        .toList();
  }

  return _showEntryDialog(
    context: context,
    storage: storage,
    onUpdate: onUpdate,
    entryToEdit: null,
    prefillTags: prefillTags,
    activeAttributeKeys: attributeOrder, // Pass the resolved order
  );
}

Future<void> showEditEntryDialog(
  BuildContext context,
  AppEntry entry,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  // Edit mode always respects the folder it was opened from
  // If opened from a "Global" search context where folder might be unknown,
  // you might need to fallback, but typically edit happens in context.
  // Using folder.visibleAttributes or activeAttributes preserves the folder's custom view.
  return _showEntryDialog(
    context: context,
    storage: storage,
    onUpdate: onUpdate,
    entryToEdit: entry,
    activeAttributeKeys: folder
        .activeAttributes, // Use active to show all editable fields in correct order
  );
}

// --- UNIFIED DIALOG IMPLEMENTATION ---

Future<void> _showEntryDialog({
  required BuildContext context,
  required StorageService storage,
  required VoidCallback onUpdate,
  AppEntry? entryToEdit,
  List<String>? prefillTags,
  List<String>? activeAttributeKeys,
}) {
  final bool isEditMode = entryToEdit != null;

  // 1. Prepare Form Data
  final Map<String, dynamic> formValues = isEditMode
      ? Map.from(entryToEdit.attributes)
      : {
          'dateCompleted': DateTime.now().toIso8601String(),
          'tag': prefillTags != null
              ? List<String>.from(prefillTags)
              : <String>[],
        };

  // 2. Get Attributes
  final customAttrs = storage.getCustomAttributes();
  final allDefs = getEntryAttributes(customAttrs);
  final defMap = {for (var d in allDefs) d.key: d};

  // 3. Determine Field Order & Visibility based on the keys passed in
  List<AttributeDefinition> formAttributes = [];
  const hiddenKeys = ['dateCreated', 'dateEdited', 'lastAddedTo'];

  if (activeAttributeKeys != null) {
    for (var key in activeAttributeKeys) {
      // Only add if it exists in definitions and isn't a hidden system key
      if (defMap.containsKey(key) && !hiddenKeys.contains(key)) {
        formAttributes.add(defMap[key]!);
      }
    }
    // Safety Fallback: Ensure 'tag' is present if somehow missed
    if (!formAttributes.any((d) => d.key == 'tag') &&
        defMap.containsKey('tag')) {
      formAttributes.add(defMap['tag']!);
    }
  } else {
    // Fallback if no keys provided (shouldn't happen with new logic, but safe)
    formAttributes = allDefs.where((d) => !hiddenKeys.contains(d.key)).toList();
  }

  // 4. Initialize Text Controllers
  final Map<String, TextEditingController> textControllers = {};
  for (var def in formAttributes) {
    if (def.key != 'tag' &&
        def.type != AttributeValueType.date &&
        def.type != AttributeValueType.rating) {
      textControllers[def.key] = TextEditingController(
        text: formValues[def.key]?.toString() ?? '',
      );
    }
  }

  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      final TextEditingController tagSearchController = TextEditingController();
      String tagSearchQuery = '';

      return StatefulBuilder(
        builder: (context, setState) {
          final allTags = storage.getGlobalTags();
          final visibleTags = allTags
              .where(
                (tag) =>
                    tag.toLowerCase().contains(tagSearchQuery.toLowerCase()),
              )
              .toList();

          return BaseBottomSheet(
            title: isEditMode ? "Edit Entry" : "New Entry",
            onSave: () async {
              textControllers.forEach((key, controller) {
                formValues[key] = controller.text;
              });

              final entry = isEditMode
                  ? entryToEdit!
                  : storage.createNewEntry();

              formValues.forEach((key, value) {
                entry.setAttribute(key, value);
              });

              await storage.saveEntry(entry);
              onUpdate();
              if (context.mounted) Navigator.pop(context);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...formAttributes.map((def) {
                  return _buildFlatFormSection(
                    context: context,
                    def: def,
                    formValues: formValues,
                    textControllers: textControllers,
                    storage: storage,
                    visibleTags: visibleTags,
                    tagSearchController: tagSearchController,
                    onTagQueryChanged: (val) =>
                        setState(() => tagSearchQuery = val),
                    onStateChange: () => setState(() {}),
                  );
                }),

                if (isEditMode) ...[
                  const SizedBox(height: 32),
                  DeleteTriggerButton(
                    label: "Delete Entry",
                    onPressed: () {
                      showDeleteConfirmationDialog(
                        context: context,
                        title: "Delete Entry?",
                        message: "Delete this entry?",
                        subtitle: "This action cannot be undone.",
                        onConfirm: () async {
                          await storage.deleteEntry(entryToEdit!.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            onUpdate();
                          }
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

// --- FLAT FORM SECTION WIDGET ---

Widget _buildFlatFormSection({
  required BuildContext context,
  required AttributeDefinition def,
  required Map<String, dynamic> formValues,
  required Map<String, TextEditingController> textControllers,
  required StorageService storage,
  required List<String> visibleTags,
  required TextEditingController tagSearchController,
  required Function(String) onTagQueryChanged,
  required VoidCallback onStateChange,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        def.label,
        style: const TextStyle(
          fontFamily: '.SF Pro Text',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Colors.black,
        ),
      ),
      const SizedBox(height: 8),

      if (def.key == 'tag') ...[
        // -- TAGS --
        CupertinoTextField(
          controller: tagSearchController,
          placeholder: "Filter tags...",
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          style: const TextStyle(fontFamily: '.SF Pro Text', fontSize: 16),
          onChanged: onTagQueryChanged,
        ),
        const SizedBox(height: 12),
        if (visibleTags.isEmpty && tagSearchController.text.isNotEmpty)
          const Text(
            "No tags found",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          )
        else if (visibleTags.isEmpty)
          const Text(
            "No tags available",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          )
        else
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
                    "#$t",
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 13,
                      color: isSelected ? Colors.black : Colors.black,
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
        // -- CALENDAR VIEW DATE PICKER --
        Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black, // Color of selected day
              onPrimary: Colors.white, // Text color of selected day
              onSurface: Colors.black, // Default text color
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CalendarDatePicker(
              initialDate:
                  DateTime.tryParse(formValues[def.key]?.toString() ?? '') ??
                  DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              onDateChanged: (picked) {
                formValues[def.key] = picked.toIso8601String();
                onStateChange();
              },
            ),
          ),
        ),
      ] else if (def.type == AttributeValueType.rating) ...[
        // -- RATING --
        Row(
          children: List.generate(5, (index) {
            final rating = (formValues[def.key] ?? 0) as int;
            return GestureDetector(
              onTap: () {
                formValues[def.key] = (rating == index + 1) ? 0 : index + 1;
                onStateChange();
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
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
        // -- STANDARD TEXT --
        CupertinoTextField(
          controller: textControllers[def.key],
          placeholder: def.type == AttributeValueType.image
              ? "Paste image URL"
              : "Enter ${def.label.toLowerCase()}...",
          padding: const EdgeInsets.all(12),
          maxLines: def.label.toLowerCase().contains('note') ? 4 : 1,
          keyboardType: def.type == AttributeValueType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          style: const TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 16,
            color: Colors.black,
          ),
          onChanged: (val) {
            formValues[def.key] = val;
            onStateChange();
          },
        ),
      ],

      const SizedBox(height: 24),
    ],
  );
}
