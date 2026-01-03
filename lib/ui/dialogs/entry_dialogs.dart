import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../app_styles.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import 'confirm_dialog.dart';

Future<void> showAddEntryDialog(
  BuildContext context,
  StorageService storage,
  VoidCallback onUpdate, {
  List<String>? prefillTags,
  AppFolder? folderContext,
}) {
  List<String>? attributeOrder;
  if (folderContext != null) {
    attributeOrder = folderContext.activeAttributes;
  } else {
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
    activeAttributeKeys: attributeOrder,
  );
}

Future<void> showEditEntryDialog(
  BuildContext context,
  AppEntry entry,
  AppFolder folder,
  StorageService storage,
  VoidCallback onUpdate,
) {
  return _showEntryDialog(
    context: context,
    storage: storage,
    onUpdate: onUpdate,
    entryToEdit: entry,
    activeAttributeKeys: folder.activeAttributes,
  );
}

Future<void> _showEntryDialog({
  required BuildContext context,
  required StorageService storage,
  required VoidCallback onUpdate,
  AppEntry? entryToEdit,
  List<String>? prefillTags,
  List<String>? activeAttributeKeys,
}) {
  final bool isEditMode = entryToEdit != null;
  final Map<String, dynamic> formValues = isEditMode
      ? Map.from(entryToEdit.attributes)
      : {
          'dateCompleted': DateTime.now().toIso8601String(),
          'tag': prefillTags != null
              ? List<String>.from(prefillTags)
              : <String>[],
        };

  final customAttrs = storage.getCustomAttributes();
  final allDefs = getEntryAttributes(customAttrs);
  final defMap = {for (var d in allDefs) d.key: d};
  List<AttributeDefinition> formAttributes = [];
  const hiddenKeys = ['dateCreated', 'dateEdited', 'lastAddedTo'];

  if (activeAttributeKeys != null) {
    for (var key in activeAttributeKeys) {
      if (defMap.containsKey(key) && !hiddenKeys.contains(key)) {
        formAttributes.add(defMap[key]!);
      }
    }
    if (!formAttributes.any((d) => d.key == 'tag') &&
        defMap.containsKey('tag')) {
      formAttributes.add(defMap['tag']!);
    }
  } else {
    formAttributes = allDefs.where((d) => !hiddenKeys.contains(d.key)).toList();
  }

  final Map<String, TextEditingController> textControllers = {};
  for (var def in formAttributes) {
    if (def.key != 'tag' &&
        def.type != AttributeValueType.date &&
        def.type != AttributeValueType.rating &&
        def.type != AttributeValueType.image) {
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
      Text(def.label, style: AppTextStyles.label),
      const SizedBox(height: 8),
      if (def.key == 'tag') ...[
        CupertinoTextField(
          controller: tagSearchController,
          placeholder: "Filter tags...",
          padding: const EdgeInsets.all(AppDimens.spacingM),
          decoration: AppDecorations.input,
          style: AppTextStyles.body,
          onChanged: onTagQueryChanged,
        ),
        const SizedBox(height: 12),
        if (visibleTags.isEmpty && tagSearchController.text.isNotEmpty)
          const Text(
            "No tags found",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          )
        else if (visibleTags.isEmpty)
          const Text(
            "No tags available",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                        ? Color.lerp(Colors.white, catColor, 0.2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(
                      AppDimens.cornerRadiusLess,
                    ),
                    border: isSelected
                        ? Border.all(color: catColor)
                        : Border.all(color: AppColors.border.withOpacity(0.3)),
                  ),
                  child: Text(
                    "#$t",
                    style: AppTextStyles.body.copyWith(
                      color: isSelected ? catColor : Colors.grey.shade800,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ] else if (def.type == AttributeValueType.date) ...[
        Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light().copyWith(
              primary: AppColors.primary,
              onPrimary: AppColors.background,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
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
      ] else if (def.type == AttributeValueType.image) ...[
        _buildImageEditor(
          context: context,
          def: def,
          formValues: formValues,
          onStateChange: onStateChange,
        ),
      ] else ...[
        CupertinoTextField(
          controller: textControllers[def.key],
          placeholder: "Enter ${def.label.toLowerCase()}...",
          padding: const EdgeInsets.all(AppDimens.spacingM),
          maxLines: def.label.toLowerCase().contains('note') ? 4 : 1,
          keyboardType: def.type == AttributeValueType.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: AppDecorations.input,
          style: AppTextStyles.body,
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

Widget _buildImageEditor({
  required BuildContext context,
  required AttributeDefinition def,
  required Map<String, dynamic> formValues,
  required VoidCallback onStateChange,
}) {
  final String? imageValue = formValues[def.key]?.toString();
  final String? sourceValue = formValues['${def.key}_source']?.toString();
  final bool hasImage = imageValue != null && imageValue.isNotEmpty;
  final bool isLocal = hasImage && !imageValue.startsWith('http');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (hasImage)
        Stack(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
                image: DecorationImage(
                  image:
                      (isLocal
                              ? FileImage(File(imageValue))
                              : NetworkImage(imageValue))
                          as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  formValues[def.key] = null;
                  formValues['${def.key}_source'] = null;
                  onStateChange();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
            if (sourceValue != null && sourceValue.isNotEmpty)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Source: $sourceValue",
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        )
      else
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
            border: Border.all(color: AppColors.border.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.photo,
                size: 32,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                "No Image Selected",
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: AppColors.inputBackground,
              child: const Text(
                "Paste Link",
                style: TextStyle(color: AppColors.primary, fontSize: 14),
              ),
              onPressed: () => _showUrlInputDialog(context, (url, source) {
                formValues[def.key] = url;
                if (source != null && source.isNotEmpty) {
                  formValues['${def.key}_source'] = source;
                }
                onStateChange();
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: AppColors.inputBackground,
              child: const Text(
                "Photos",
                style: TextStyle(color: AppColors.primary, fontSize: 14),
              ),
              onPressed: () async {
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  formValues[def.key] = image.path;
                  formValues['${def.key}_source'] =
                      null; // Clear source for local
                  onStateChange();
                }
              },
            ),
          ),
        ],
      ),
    ],
  );
}

void _showUrlInputDialog(
  BuildContext context,
  Function(String url, String? source) onConfirm,
) {
  final urlController = TextEditingController();

  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text("Add Image from Web"),
      content: Column(
        children: [
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: urlController,
            placeholder: "Image URL (Required)",
            autofocus: true,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Cancel"),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            if (urlController.text.isNotEmpty) {
              onConfirm(urlController.text, urlController.text);
              Navigator.pop(ctx);
            }
          },
          child: const Text("Add"),
        ),
      ],
    ),
  );
}
