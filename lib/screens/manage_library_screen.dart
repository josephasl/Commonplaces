import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../storage_service.dart';
import '../../attributes.dart';
import '../../models.dart';
import '../dialogs.dart';
import '../ui/app_styles.dart';
import 'edit_tags_screen.dart';
import '../ui/widgets/common_ui.dart';

// Sort Options Enum
enum AttributeSortOption { nameAsc, nameDesc, dateNewest, dateOldest }

class ManageLibraryScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;

  const ManageLibraryScreen({super.key, required this.storage, this.onUpdate});

  @override
  State<ManageLibraryScreen> createState() => ManageLibraryScreenState();
}

class ManageLibraryScreenState extends State<ManageLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<EditTagsScreenState> _editTagsKey = GlobalKey();
  final ScrollController _attributesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.storage.getManageLibraryTabIndex();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );

    _tabController.addListener(() {
      setState(() {});
      if (!_tabController.indexIsChanging) {
        widget.storage.saveManageLibraryTabIndex(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _attributesScrollController.dispose();
    super.dispose();
  }

  void handleNavTap() {
    if (_tabController.index == 0) {
      _editTagsKey.currentState?.scrollToTop();
    } else {
      if (_attributesScrollController.hasClients) {
        _attributesScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _refresh() {
    setState(() {});
    widget.onUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.white,

        elevation: 0,
        centerTitle: true,
        title: const Text("Manage Library", style: AppTextStyles.header),
        actions: [
          // ADD BUTTON: Only show "New Category" icon on the Stamps Tab.
          // The Attributes Tab uses a floating button.
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(
                CupertinoIcons.folder_badge_plus,
                color: AppColors.primary,
              ),
              tooltip: "New Category",
              onPressed: () {
                showAddCategoryDialog(context, widget.storage, _refresh);
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.divider, height: 1.0),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              EditTagsScreen(
                key: _editTagsKey,
                storage: widget.storage,
                onUpdate: widget.onUpdate,
              ),
              _AttributesManager(
                storage: widget.storage,
                onUpdate: widget.onUpdate,
                scrollController: _attributesScrollController,
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: AppSlidingSegmentedControl<int>(
                groupValue: _tabController.index,
                children: const {0: "Stamps", 1: "Attributes"},
                onValueChanged: (index) => _tabController.animateTo(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributesManager extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;
  final ScrollController scrollController;

  const _AttributesManager({
    required this.storage,
    this.onUpdate,
    required this.scrollController,
  });

  @override
  State<_AttributesManager> createState() => _AttributesManagerState();
}

class _AttributesManagerState extends State<_AttributesManager> {
  void _refresh() {
    setState(() {});
    widget.onUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get ALL attributes (System + Custom), sorted by user preference (drag order)
    final allAttributes = widget.storage.getSortedAttributeDefinitions();

    return Container(
      color: AppColors.coloredBackground,
      child: Stack(
        children: [
          ReorderableListView.builder(
            scrollController: widget.scrollController,
            key: const PageStorageKey('attributes_list'),
            padding: const EdgeInsets.fromLTRB(0, 68, 0, 100),
            itemCount: allAttributes.length,
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                color: Colors.transparent,
                shadowColor: Colors.black26,
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) async {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = allAttributes.removeAt(oldIndex);
                allAttributes.insert(newIndex, item);
              });
              // Save new order to storage
              final keys = allAttributes.map((a) => a.key).toList();
              await widget.storage.saveAttributeSortOrder(keys);
            },
            itemBuilder: (context, index) {
              final attr = allAttributes[index];
              final isSystem = attr.isSystemField;
              final isLast = index == allAttributes.length - 1;

              return Container(
                key: ValueKey(attr.key),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  // Grouped style rounding
                  borderRadius: BorderRadius.vertical(
                    top: index == 0
                        ? const Radius.circular(AppDimens.cornerRadius)
                        : Radius.zero,
                    bottom: isLast
                        ? const Radius.circular(AppDimens.cornerRadius)
                        : Radius.zero,
                  ),
                ),
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        // Only Custom attributes are editable
                        onTap: isSystem
                            ? null
                            : () {
                                showAttributeOptionsDialog(
                                  context,
                                  widget.storage,
                                  attr,
                                  _refresh,
                                );
                              },
                        borderRadius: BorderRadius.vertical(
                          top: index == 0
                              ? const Radius.circular(AppDimens.cornerRadius)
                              : Radius.zero,
                          bottom: isLast
                              ? const Radius.circular(AppDimens.cornerRadius)
                              : Radius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              // Reorder Handle
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

                              // Label
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attr.label,
                                      style: AppTextStyles.body.copyWith(
                                        color: isSystem
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                        fontWeight: isSystem
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      attr.type.name.toUpperCase(),
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Edit Icon or Lock
                              if (isSystem)
                                const Icon(
                                  CupertinoIcons.lock_fill,
                                  size: 14,
                                  color: CupertinoColors.systemGrey4,
                                )
                              else
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
                        indent: 44, // Align with text
                        color: AppColors.divider,
                      ),
                  ],
                ),
              );
            },
          ),

          // --- FLOATING ADD BUTTON (Restored) ---
          Positioned(
            bottom: 20,
            right: 16,
            child: AppFloatingButton(
              icon: CupertinoIcons.add,
              color: AppColors.primary,
              iconColor: Colors.white,
              onTap: () =>
                  showAddAttributeDialog(context, widget.storage, _refresh),
            ),
          ),
        ],
      ),
    );
  }
}
