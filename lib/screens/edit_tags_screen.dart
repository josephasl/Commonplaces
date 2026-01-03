import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../ui/app_styles.dart';
import '../dialogs.dart';
import '../ui/widgets/common_ui.dart';

class EditTagsScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;

  const EditTagsScreen({super.key, required this.storage, this.onUpdate});

  @override
  State<EditTagsScreen> createState() => EditTagsScreenState();
}

class EditTagsScreenState extends State<EditTagsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

    List<String> visibleTags = allTags;
    if (_searchQuery.isNotEmpty) {
      visibleTags = allTags
          .where((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    final Map<String, List<String>> grouped = {};
    for (var cat in categories) grouped[cat.id] = [];
    if (!grouped.containsKey('default_grey_cat'))
      grouped['default_grey_cat'] = [];

    for (var tag in visibleTags) {
      final catId = mapping[tag] ?? 'default_grey_cat';
      if (grouped.containsKey(catId))
        grouped[catId]!.add(tag);
      else
        grouped['default_grey_cat']?.add(tag);
    }

    return Container(
      color: AppColors.coloredBackground,
      child: Stack(
        children: [
          ReorderableListView.builder(
            scrollController: _scrollController,
            key: const PageStorageKey('edit_tags_list'),
            padding: const EdgeInsets.fromLTRB(0, 60, 0, 100),
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
                color: Colors.transparent,
                shadowColor: Colors.black26,
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final cat = categories[index];
              final catTags = grouped[cat.id] ?? [];
              if (catTags.isEmpty && _searchQuery.isNotEmpty)
                return Container(key: ValueKey(cat.id));
              final isUncategorized = cat.id == 'default_grey_cat';

              return Container(
                key: ValueKey(cat.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(
                                CupertinoIcons.bars,
                                color: CupertinoColors.systemGrey3,
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
                          Expanded(
                            child: Text(
                              cat.name.toUpperCase(),
                              style: AppTextStyles.subHeader,
                            ),
                          ),
                          if (!isUncategorized)
                            GestureDetector(
                              onTap: () => showEditCategoryDialog(
                                context,
                                widget.storage,
                                cat,
                                _refresh,
                              ),
                              child: const Text(
                                "Edit",
                                style: TextStyle(
                                  fontFamily: '.SF Pro Text',
                                  fontSize: 13,
                                  color: CupertinoColors.activeBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (catTags.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: AppDecorations.groupedItem,
                        child: Text(
                          "No tags in this category",
                          style: AppTextStyles.body.copyWith(
                            color: Colors.grey.shade400,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: AppDecorations.groupedItem,
                        child: Column(
                          children: List.generate(catTags.length, (tagIndex) {
                            final tag = catTags[tagIndex];
                            final isLast = tagIndex == catTags.length - 1;
                            return Column(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => showTagOptionsDialog(
                                      context,
                                      widget.storage,
                                      tag,
                                      _refresh,
                                    ),
                                    borderRadius: isLast
                                        ? const BorderRadius.vertical(
                                            bottom: Radius.circular(
                                              AppDimens.cornerRadius,
                                            ),
                                          )
                                        : (tagIndex == 0
                                              ? const BorderRadius.vertical(
                                                  top: Radius.circular(
                                                    AppDimens.cornerRadius,
                                                  ),
                                                )
                                              : BorderRadius.zero),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            "#$tag",
                                            style: AppTextStyles.body,
                                          ),
                                          const Spacer(),
                                          const Icon(
                                            CupertinoIcons.right_chevron,
                                            size: 14,
                                            color: CupertinoColors.systemGrey3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 16,
                                    color: Color(0xFFF0F0F0),
                                  ),
                              ],
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: "Filter stamps...",
                    showClear: _searchQuery.isNotEmpty,
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: AppDimens.spacingM),
                AppFloatingButton(
                  icon: Icons.add,
                  color: AppColors.primary,
                  iconColor: Colors.white,
                  onTap: () =>
                      showAddTagDialog(context, widget.storage, _refresh),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
