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
  State<EditTagsScreen> createState() => EditTagsScreenState();
}

// Public State class so we can access scrollToTop via GlobalKey
class EditTagsScreenState extends State<EditTagsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // NEW
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose(); // NEW
    super.dispose();
  }

  // --- NEW: Public method called by parent ---
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _refresh() {
    setState(() {});
    widget.onUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
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

    // Group Tags
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

    return Stack(
      children: [
        ReorderableListView.builder(
          scrollController: _scrollController, // NEW: Attach controller
          key: const PageStorageKey('edit_tags_list'),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
          itemCount: categories.length,
          // ... [rest of ReorderableListView remains the same] ...
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

                        // --- UPDATED ACTIONS: Single Ellipsis Button ---
                        if (cat.id != 'default_grey_cat')
                          GestureDetector(
                            onTap: () => showEditCategoryDialog(
                              context,
                              widget.storage,
                              cat,
                              _refresh,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: const Icon(
                                CupertinoIcons.ellipsis,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ),
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
                              onTap: () => showTagOptionsDialog(
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

        // ... [Floating Search + Add Tag code remains exactly the same] ...
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
              GestureDetector(
                onTap: () =>
                    showAddTagDialog(context, widget.storage, _refresh),
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
