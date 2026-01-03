import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../app_styles.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import '../widgets/common_ui.dart';
import 'confirm_dialog.dart';
import 'tag_dialogs.dart';

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
  int selectedIconIndex = isEditMode ? folderToEdit!.iconIndex : 0;

  return showCupertinoModalPopup(
    context: context,
    builder: (context) {
      final List<String> globalTags = storage.getGlobalTags();
      List<String> availableTags;
      if (isEditMode) {
        availableTags = List.from(folderToEdit!.displayTags);
        for (var tag in globalTags) {
          if (!availableTags.contains(tag)) {
            availableTags.add(tag);
          }
        }
        availableTags.removeWhere((t) => !globalTags.contains(t));
      } else {
        availableTags = List.from(globalTags);
      }
      List<String> selectedTags = isEditMode
          ? List.from(folderToEdit!.displayTags)
          : [];
      final allDefinitions = storage.getSortedAttributeDefinitions();
      final Set<String> activeSet = isEditMode
          ? Set.from(folderToEdit!.activeAttributes)
          : {'tag'};
      final Set<String> visibleSet = isEditMode
          ? Set.from(folderToEdit!.visibleAttributes)
          : {'tag'};
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
            title: isEditMode ? "Edit Commonplace" : "New Commonplace",
            onSave: () async {
              if (titleController.text.isNotEmpty) {
                final folder = isEditMode
                    ? folderToEdit!
                    : storage.createNewFolder();
                folder.setAttribute('title', titleController.text);
                selectedTags.sort(
                  (a, b) => availableTags
                      .indexOf(a)
                      .compareTo(availableTags.indexOf(b)),
                );
                folder.setAttribute('displayTags', selectedTags);
                folder.setAttribute('iconIndex', selectedIconIndex);
                List<String> newActiveList = [];
                List<String> newVisibleList = [];
                for (var def in sortedAttributes) {
                  if (activeSet.contains(def.key)) newActiveList.add(def.key);
                  if (visibleSet.contains(def.key)) newVisibleList.add(def.key);
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
                const Text("Icon", style: AppTextStyles.label),
                const SizedBox(height: AppDimens.spacingS),
                AppIconPicker(
                  selectedIndex: selectedIconIndex,
                  onSelect: (i) => setState(() => selectedIconIndex = i),
                ),
                const SizedBox(height: AppDimens.spacingL),
                const Text("Name", style: AppTextStyles.label),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: titleController,
                  placeholder: "New folder",
                  padding: const EdgeInsets.all(AppDimens.spacingM),
                  decoration: AppDecorations.input,
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [const Text("Stamps", style: AppTextStyles.label)],
                ),
                const SizedBox(height: 12),
                if (availableTags.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "No tags available",
                      style: TextStyle(color: AppColors.textSecondary),
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
                                ? Color.lerp(Colors.white, catColor, 0.2)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(
                              AppDimens.cornerRadiusLess,
                            ),
                            border: isSelected
                                ? Border.all(color: catColor)
                                : Border.all(
                                    color: AppColors.border.withOpacity(0.3),
                                  ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.bars,
                                size: 14,
                                color: isSelected
                                    ? catColor
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "#$tag",
                                style: AppTextStyles.body.copyWith(
                                  color: isSelected
                                      ? catColor
                                      : Colors.grey.shade800,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(
                      child: Text("Attributes", style: AppTextStyles.label),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: Theme(
                    data: ThemeData(
                      canvasColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: ReorderableListView.builder(
                      physics: const ClampingScrollPhysics(),
                      itemCount: sortedAttributes.length,
                      onReorder: _onAttrReorder,
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
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(
                              top: index == 0
                                  ? const Radius.circular(
                                      AppDimens.cornerRadius,
                                    )
                                  : Radius.zero,
                              bottom: isLast
                                  ? const Radius.circular(
                                      AppDimens.cornerRadius,
                                    )
                                  : Radius.zero,
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
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
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        def.label,
                                        style: AppTextStyles.body.copyWith(
                                          color: isActive
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
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
                                        color: (isActive
                                            ? (isVisible
                                                  ? CupertinoColors.activeBlue
                                                  : AppColors.textSecondary)
                                            : AppColors.textSecondary
                                                  .withOpacity(0.3)),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 44,
                                  color: AppColors.divider,
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
