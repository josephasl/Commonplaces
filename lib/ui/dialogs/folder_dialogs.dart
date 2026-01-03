import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderables/reorderables.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../app_styles.dart';
import '../widgets/base_bottom_sheet.dart';
import '../widgets/delete_trigger_button.dart';
import '../widgets/app_segmented_control.dart';
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
  String selectedCoverType = isEditMode ? folderToEdit!.coverType : 'icon';
  String selectedEmoji = (isEditMode && folderToEdit!.coverType == 'emoji')
      ? folderToEdit!.coverValue
      : '📁';
  final TextEditingController emojiController = TextEditingController(
    text: selectedEmoji,
  );
  String? selectedImagePath = (isEditMode && folderToEdit!.coverType == 'image')
      ? folderToEdit!.coverValue
      : null;
  String? selectedImageSource = isEditMode
      ? folderToEdit!.getAttribute('coverImageSource')
      : null;
  String selectedLayout = isEditMode ? folderToEdit!.layout : 'grid';

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
                if (selectedCoverType == 'emoji') {
                  folder.setCover('emoji', emojiController.text);
                } else if (selectedCoverType == 'image') {
                  folder.setCover('image', selectedImagePath ?? '');
                  folder.setAttribute('coverImageSource', selectedImageSource);
                } else {
                  folder.setCover('icon', selectedIconIndex.toString());
                }
                folder.setLayout(selectedLayout);
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
                const Text("Cover", style: AppTextStyles.label),
                const SizedBox(height: AppDimens.spacingS),
                AppSlidingSegmentedControl<String>(
                  groupValue: selectedCoverType,
                  children: const {
                    'icon': 'Icon',
                    'emoji': 'Emoji',
                    'image': 'Image',
                  },
                  onValueChanged: (val) {
                    setState(() => selectedCoverType = val);
                  },
                ),
                const SizedBox(height: AppDimens.spacingM),
                if (selectedCoverType == 'icon')
                  AppIconPicker(
                    selectedIndex: selectedIconIndex,
                    onSelect: (i) => setState(() => selectedIconIndex = i),
                  )
                else if (selectedCoverType == 'emoji')
                  Center(
                    child: SizedBox(
                      width: 100,
                      child: CupertinoTextField(
                        controller: emojiController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 40),
                        maxLength: 1,
                        decoration: AppDecorations.input,
                      ),
                    ),
                  )
                else if (selectedCoverType == 'image')
                  _buildFolderImageEditor(
                    context,
                    selectedImagePath,
                    selectedImageSource,
                    (path, source) => setState(() {
                      selectedImagePath = path;
                      selectedImageSource = source;
                    }),
                  ),
                const SizedBox(height: AppDimens.spacingL),
                const Text("Layout", style: AppTextStyles.label),
                const SizedBox(height: AppDimens.spacingS),
                AppSlidingSegmentedControl<String>(
                  groupValue: selectedLayout,
                  children: const {
                    'grid': 'Grid',
                    'list': 'List',
                    'board': 'Board',
                  },
                  onValueChanged: (val) => setState(() => selectedLayout = val),
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

Widget _buildFolderImageEditor(
  BuildContext context,
  String? imagePath,
  String? imageSource,
  Function(String? path, String? source) onUpdate,
) {
  final bool hasImage = imagePath != null && imagePath.isNotEmpty;
  final bool isLocal = hasImage && !imagePath.startsWith('http');

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
                              ? FileImage(File(imagePath))
                              : NetworkImage(imagePath))
                          as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => onUpdate(null, null),
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
            if (imageSource != null && imageSource.isNotEmpty)
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
                    "Source: $imageSource",
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
                onUpdate(url, source);
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
                  onUpdate(image.path, null);
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
