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

  // --- 1. Tag Options Sheet (Now matches 'Move Tag' style) ---
  void _showTagOptions(String tag) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _buildBottomSheet(
        context: context,
        title: "Manage Tag",
        hideSave: true, // No save button, just a list of actions
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Center(
                child: Text(
                  "#$tag",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            _buildOptionTile(
              icon: CupertinoIcons.pencil,
              label: "Rename Tag",
              color: Colors.black,
              onTap: () {
                Navigator.pop(ctx);
                _showRenameSheet(tag);
              },
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: CupertinoIcons.folder_badge_plus,
              label: "Move to Category",
              color: Colors.black,
              onTap: () {
                Navigator.pop(ctx);
                showMoveTagDialog(context, widget.storage, tag, _refresh);
              },
            ),
            const Divider(height: 1),
            _buildOptionTile(
              icon: CupertinoIcons.trash,
              label: "Delete Tag",
              color: CupertinoColors.destructiveRed,
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(tag);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              CupertinoIcons.right_chevron,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Rename Tag (Matches 'New Category' style) ---
  void _showRenameSheet(String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _buildBottomSheet(
        context: context,
        title: "Rename Tag",
        onSave: () async {
          if (controller.text.isNotEmpty && controller.text != oldTag) {
            await widget.storage.renameGlobalTag(oldTag, controller.text);
            _refresh();
            if (context.mounted) Navigator.pop(ctx);
          }
        },
        child: Column(
          children: [
            CupertinoTextField(
              controller: controller,
              placeholder: "New Name",
              padding: const EdgeInsets.all(12),
              autofocus: true,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
              onSubmitted: (_) async {
                if (controller.text.isNotEmpty && controller.text != oldTag) {
                  await widget.storage.renameGlobalTag(oldTag, controller.text);
                  _refresh();
                  if (context.mounted) Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Add Tag (Matches 'New Category' style) ---
  void _showAddTagSheet() {
    final controller = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => _buildBottomSheet(
        context: context,
        title: "New Tag",
        onSave: () async {
          if (controller.text.isNotEmpty) {
            await widget.storage.addGlobalTag(controller.text);
            _refresh();
            if (context.mounted) Navigator.pop(ctx);
          }
        },
        child: Column(
          children: [
            CupertinoTextField(
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
          ],
        ),
      ),
    );
  }

  // --- Helper: Shared Bottom Sheet Builder (Matches dialogs.dart) ---
  Widget _buildBottomSheet({
    required BuildContext context,
    required String title,
    Widget? child,
    VoidCallback? onSave,
    bool hideSave = false,
  }) {
    return Padding(
      // Handle keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        // Dynamic height, max 90%
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
              // Drag Handle
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
              // Header
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
              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (child != null) child,
                      const SizedBox(height: 24), // Extra bottom padding
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
