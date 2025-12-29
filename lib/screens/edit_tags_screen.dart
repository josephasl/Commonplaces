import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../storage_service.dart';
import '../models.dart';
import '../dialogs.dart';

class EditTagsScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;

  const EditTagsScreen({super.key, required this.storage, this.onUpdate});

  @override
  State<EditTagsScreen> createState() => _EditTagsScreenState();
}

class _EditTagsScreenState extends State<EditTagsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
    widget.onUpdate?.call();
  }

  // --- UPDATED: Tag Options (Custom Bottom Sheet) ---
  void _showTagOptions(String tag) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        // Set a fixed height or let it wrap content.
        // Using wrap (mainAxisSize.min) feels more natural for a short menu.
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false, // Don't need top safe area inside the sheet
            child: Column(
              mainAxisSize: MainAxisSize.min, // Wrap content
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      Expanded(
                        child: Text(
                          "Manage Tag: #$tag",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 60), // Spacer to balance "Cancel"
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // OPTIONS LIST
                ListTile(
                  leading: const Icon(
                    CupertinoIcons.pencil,
                    color: Colors.black,
                  ),
                  title: const Text("Rename Tag"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRenameSheet(tag);
                  },
                ),
                const Divider(height: 1, indent: 56), // Separator
                ListTile(
                  leading: const Icon(
                    CupertinoIcons.folder_badge_plus,
                    color: Colors.black,
                  ),
                  title: const Text("Move to Category"),
                  onTap: () {
                    Navigator.pop(ctx);
                    showMoveTagDialog(context, widget.storage, tag, _refresh);
                  },
                ),
                const Divider(height: 1, indent: 56), // Separator
                ListTile(
                  leading: const Icon(
                    CupertinoIcons.trash,
                    color: CupertinoColors.destructiveRed,
                  ),
                  title: const Text(
                    "Delete Tag",
                    style: TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDeleteConfirm(tag);
                  },
                ),
                const SizedBox(height: 20), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Rename Tag (Bottom Sheet Style) ---
  void _showRenameSheet(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _buildInputBottomSheet(
        title: "Rename Tag",
        actionLabel: "Save",
        controller: controller,
        placeholder: "New Name",
        onSave: () async {
          if (controller.text.isNotEmpty && controller.text != oldTag) {
            await widget.storage.renameGlobalTag(oldTag, controller.text);
            _refresh();
            if (context.mounted) Navigator.pop(ctx);
          }
        },
      ),
    );
  }

  // --- Add Tag (Bottom Sheet Style) ---
  void _showAddTagSheet() {
    final controller = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          // Allow shrink wrap, max 90%
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
              mainAxisSize: MainAxisSize.min, // Shrink vertically
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "New Tag",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          "Create",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          if (controller.text.isNotEmpty) {
                            await widget.storage.addGlobalTag(controller.text);
                            _refresh();
                            if (context.mounted) Navigator.pop(ctx);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: Colors.grey.shade200),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CupertinoTextField(
                    controller: controller,
                    placeholder: "Tag Name",
                    padding: const EdgeInsets.all(12),
                    autofocus: true,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSubmitted: (_) async {
                      if (controller.text.isNotEmpty) {
                        await widget.storage.addGlobalTag(controller.text);
                        _refresh();
                        if (context.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widget for Input Bottom Sheets ---
  Widget _buildInputBottomSheet({
    required String title,
    required String actionLabel,
    required TextEditingController controller,
    required String placeholder,
    required VoidCallback onSave,
  }) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
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
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onSave,
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.grey.shade200),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CupertinoTextField(
                      controller: controller,
                      placeholder: placeholder,
                      padding: const EdgeInsets.all(12),
                      autofocus: true,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSubmitted: (_) => onSave(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Delete Confirmation (Keep generic alert for dangerous actions) ---
  void _showDeleteConfirm(String tag) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Delete Tag?"),
        content: Text("Delete #$tag? It will be removed from all entries."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Delete"),
            onPressed: () async {
              await widget.storage.removeGlobalTag(tag);
              _refresh();
              if (context.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get Data
    final categories = widget.storage.getTagCategories();
    final mapping = widget.storage.getTagMapping();
    final allTags = widget.storage.getGlobalTags();

    // Filter tags
    List<String> visibleTags = allTags;
    if (_searchQuery.isNotEmpty) {
      visibleTags = allTags
          .where((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // 2. Group Tags
    final Map<String, List<String>> grouped = {};
    for (var cat in categories) {
      grouped[cat.id] = [];
    }
    for (var tag in visibleTags) {
      final catId = mapping[tag] ?? 'default_grey_cat';
      if (grouped.containsKey(catId)) {
        grouped[catId]!.add(tag);
      } else {
        if (!grouped.containsKey('default_grey_cat')) {
          grouped['default_grey_cat'] = [];
        }
        grouped['default_grey_cat']?.add(tag);
      }
    }

    // 3. Build UI
    return Stack(
      children: [
        ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
          itemCount: categories.length,
          onReorder: (oldIndex, newIndex) async {
            setState(() {
              if (oldIndex < newIndex) newIndex -= 1;
              final item = categories.removeAt(oldIndex);
              categories.insert(newIndex, item);
            });
            await widget.storage.reorderTagCategories(
              oldIndex,
              newIndex < oldIndex ? newIndex : newIndex + 1,
            );
            widget.onUpdate?.call();
          },
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 4,
              color: Colors.white,
              shadowColor: Colors.black26,
              child: child,
            );
          },
          itemBuilder: (context, index) {
            final cat = categories[index];
            final catTags = grouped[cat.id] ?? [];

            if (catTags.isEmpty && _searchQuery.isNotEmpty) {
              return Container(key: ValueKey(cat.id));
            }

            return Container(
              key: ValueKey(cat.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CATEGORY HEADER ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Colors.grey.shade50,
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(
                              CupertinoIcons.bars,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                        Icon(
                          AppConstants.categoryIcons[cat.iconIndex],
                          color: AppConstants.categoryColors[cat.colorIndex],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        // Category Actions
                        if (cat.id != 'default_grey_cat') ...[
                          GestureDetector(
                            onTap: () => showEditCategoryDialog(
                              context,
                              widget.storage,
                              cat,
                              _refresh,
                            ),
                            child: const Icon(
                              CupertinoIcons.pencil,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              showCupertinoDialog(
                                context: context,
                                builder: (c) => CupertinoAlertDialog(
                                  title: const Text("Delete Category?"),
                                  content: Text(
                                    "Delete '${cat.name}'? Tags inside will become Uncategorized.",
                                  ),
                                  actions: [
                                    CupertinoDialogAction(
                                      child: const Text("Cancel"),
                                      onPressed: () => Navigator.pop(c),
                                    ),
                                    CupertinoDialogAction(
                                      isDestructiveAction: true,
                                      child: const Text("Delete"),
                                      onPressed: () async {
                                        Navigator.pop(c);
                                        await widget.storage.deleteTagCategory(
                                          cat.id,
                                        );
                                        _refresh();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Icon(
                              CupertinoIcons.trash,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),

                  // --- TAGS LIST ---
                  if (catTags.isNotEmpty)
                    Column(
                      children: catTags
                          .map(
                            (tag) => ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 54,
                                right: 16,
                              ),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text("#$tag"),
                              trailing: const Icon(
                                CupertinoIcons.ellipsis,
                                size: 16,
                                color: Colors.grey,
                              ),
                              onTap: () => _showTagOptions(tag),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
        ),

        // Floating Search + Add Tag
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search tags...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        CupertinoIcons.search,
                        color: Colors.black54,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // --- UPDATED ADD BUTTON ---
              GestureDetector(
                onTap: _showAddTagSheet,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
