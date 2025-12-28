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

  @override
  Widget build(BuildContext context) {
    // 1. Get Data
    final categories = widget.storage
        .getTagCategories(); // Now Sorted by sortOrder
    final mapping = widget.storage.getTagMapping();
    final allTags = widget.storage.getGlobalTags();

    // Filter tags first
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
        grouped['default_grey_cat']?.add(tag);
      }
    }

    // 3. Build UI
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Manage Tags",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.folder_badge_plus,
              color: Colors.black,
            ),
            tooltip: "New Category",
            onPressed: () =>
                showAddCategoryDialog(context, widget.storage, _refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          // REORDERABLE LIST
          // Note: ReorderableListView requires a unique key for each item
          ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) async {
              // Update state immediately for UI smoothness
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = categories.removeAt(oldIndex);
                categories.insert(newIndex, item);
              });
              // Persist to storage
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

              // If searching and no tags match in this category, hide it
              // (But ReorderableListView doesn't like shrinking items to 0 size easily,
              // so we just return an empty container if hidden, but keep the key)
              if (catTags.isEmpty && _searchQuery.isNotEmpty) {
                return Container(key: ValueKey(cat.id));
              }

              return Container(
                key: ValueKey(cat.id), // Key is crucial
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
                          // BURGER HANDLE (Drag Listener)
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

                          // Edit & Delete
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
                                          await widget.storage
                                              .deleteTagCategory(cat.id);
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
                    // Note: We cannot put a ListView inside a ReorderableListView easily.
                    // We render tags as a simple Column of tiles.
                    if (catTags.isNotEmpty)
                      Column(
                        children: catTags
                            .map(
                              (tag) => ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 54,
                                  right: 16,
                                ), // Indented to align past burger
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                title: Text("#$tag"),
                                trailing: const Icon(
                                  CupertinoIcons.right_chevron,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                onTap: () => showMoveTagDialog(
                                  context,
                                  widget.storage,
                                  tag,
                                  _refresh,
                                ),
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
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.grey,
                                ),
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
                GestureDetector(
                  onTap: () async {
                    final TextEditingController controller =
                        TextEditingController();
                    await showCupertinoDialog(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text("New Tag"),
                        content: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: CupertinoTextField(
                            controller: controller,
                            placeholder: "Tag Name",
                          ),
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text("Cancel"),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          CupertinoDialogAction(
                            child: const Text("Create"),
                            onPressed: () async {
                              if (controller.text.isNotEmpty) {
                                await widget.storage.addGlobalTag(
                                  controller.text,
                                );
                                Navigator.pop(ctx);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                    _refresh();
                  },
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
      ),
    );
  }
}
