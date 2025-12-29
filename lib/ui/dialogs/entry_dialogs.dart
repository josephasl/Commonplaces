import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart'; // Import
import 'confirm_dialog.dart';

// ... [showAddEntryDialog remains unchanged] ...
Future<void> showAddEntryDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate, {
  List<String>? prefillTags,
  List<String>? restrictToAttributes,
}) {
  // ... (Existing code) ...
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

          return BaseBottomSheet(
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
                  context: context,
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
                );
              }).toList(),
            ),
          );
        },
      );
    },
  );
}

// ... [showEditEntryDialog UPDATED] ...
Future<void> showEditEntryDialog(
  BuildContext context,
  AppEntry entry,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  // ... (Existing setup logic) ...
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

          return BaseBottomSheet(
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
                    context: context,
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
                  );
                }),
                const SizedBox(height: 32),

                // --- UNIFIED DELETE BUTTON ---
                DeleteTriggerButton(
                  label: "Delete Entry",
                  onPressed: () {
                    showDeleteConfirmationDialog(
                      context: context,
                      title: "Delete Entry?",
                      message: "Delete this entry?",
                      subtitle: "This action cannot be undone.",
                      onConfirm: () async {
                        await storage.deleteEntry(entry.id);
                        if (context.mounted) {
                          Navigator.pop(context); // Close edit dialog
                          onUpdate();
                        }
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

// ... [_buildFormSection remains unchanged] ...
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
  /* same code */
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
          def.key == 'tag'
              ? ((formValues['tag'] as List?)?.isEmpty ?? true
                    ? "No tags"
                    : "${(formValues['tag'] as List).length} selected")
              : (formValues[def.key]?.toString().isEmpty ?? true
                    ? "Empty"
                    : formValues[def.key].toString()),
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
