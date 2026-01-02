import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../storage_service.dart';
import '../../attributes.dart';
import '../../models.dart';
import '../dialogs.dart';
import '../ui/app_styles.dart';
import 'edit_tags_screen.dart';

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
      if (!_tabController.indexIsChanging) {
        widget.storage.saveManageLibraryTabIndex(_tabController.index);
        setState(() {});
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
          preferredSize: const Size.fromHeight(60.0),
          child: Column(
            children: [
              Container(color: AppColors.border.withOpacity(0.2), height: 1.0),
              const SizedBox(height: 3),
              Container(
                height: 36,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.subHeader,
                  tabs: const [
                    Tab(text: "Stamp Groups"),
                    Tab(text: "Attributes"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
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
      color: AppColors.groupedBackground,
      child: Stack(
        children: [
          ReorderableListView.builder(
            scrollController: widget.scrollController,
            key: const PageStorageKey('attributes_list'),
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 100),
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
                    top: index == 0 ? const Radius.circular(10) : Radius.zero,
                    bottom: isLast ? const Radius.circular(10) : Radius.zero,
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
                              ? const Radius.circular(10)
                              : Radius.zero,
                          bottom: isLast
                              ? const Radius.circular(10)
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
            child: GestureDetector(
              onTap: () =>
                  showAddAttributeDialog(context, widget.storage, _refresh),
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(CupertinoIcons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
