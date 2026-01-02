import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../storage_service.dart';
import '../attributes.dart';
import '../models.dart';
import '../dialogs.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Manage Library",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            fontFamily: '.SF Pro Text',
          ),
        ),
        // REMOVED: actions: [] (The + button is now floating in the tabs)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Column(
            children: [
              Container(color: Colors.grey.shade200, height: 1.0),
              const SizedBox(height: 3),
              Container(
                height: 36,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white,
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
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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
  AttributeSortOption _currentSort = AttributeSortOption.dateNewest;

  void _refresh() {
    setState(() {});
    widget.onUpdate?.call();
  }

  // Helper to extract timestamp from key
  int _getTimestamp(String key) {
    try {
      final parts = key.split('_');
      if (parts.length > 1) {
        return int.parse(parts.last);
      }
    } catch (_) {}
    return 0;
  }

  void _showSortSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("Sort Attributes By"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = AttributeSortOption.nameAsc);
              Navigator.pop(ctx);
            },
            child: const Text("Name (A-Z)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = AttributeSortOption.nameDesc);
              Navigator.pop(ctx);
            },
            child: const Text("Name (Z-A)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = AttributeSortOption.dateNewest);
              Navigator.pop(ctx);
            },
            child: const Text("Date Created (Newest)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = AttributeSortOption.dateOldest);
              Navigator.pop(ctx);
            },
            child: const Text("Date Created (Oldest)"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get ALL attributes (System + Custom), sorted by user preference
    final allAttributes = widget.storage.getSortedAttributeDefinitions();

    // 2. Apply temporary local sort if needed (optional overlay on top of saved order)
    // Note: Reordering disables local sorting usually, but here we sort for display
    // or respect drag order. If drag happens, we usually want "Custom Order".
    // For simplicity, we respect the storage order primarily. If _currentSort is set,
    // we re-sort the list temporarily.
    if (_currentSort != AttributeSortOption.dateNewest) {
      allAttributes.sort((a, b) {
        switch (_currentSort) {
          case AttributeSortOption.nameAsc:
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
          case AttributeSortOption.nameDesc:
            return b.label.toLowerCase().compareTo(a.label.toLowerCase());
          case AttributeSortOption.dateOldest:
            return _getTimestamp(a.key).compareTo(_getTimestamp(b.key));
          case AttributeSortOption.dateNewest:
          default:
            return _getTimestamp(b.key).compareTo(_getTimestamp(a.key));
        }
      });
    }

    return Container(
      color: const Color(0xFFF2F2F7),
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
              // Reset sort to 'dateNewest' (which effectively means "Custom/Manual")
              // so the drag sticks visually.
              setState(() {
                _currentSort = AttributeSortOption.dateNewest;
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
                  color: Colors.white,
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
                                      style: TextStyle(
                                        fontFamily: '.SF Pro Text',
                                        fontSize: 14,
                                        color: isSystem
                                            ? Colors.grey.shade700
                                            : Colors.black,
                                        fontWeight: isSystem
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      attr.type.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: '.SF Pro Text',
                                        fontSize: 10,
                                        color: CupertinoColors.systemGrey,
                                        fontWeight: FontWeight.w600,
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
                        color: Color(0xFFF0F0F0),
                      ),
                  ],
                ),
              );
            },
          ),

          // --- FLOATING ACTION BUTTONS ---
          Positioned(
            bottom: 20,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 2. Add Button (Black Circle)
                GestureDetector(
                  onTap: () =>
                      showAddAttributeDialog(context, widget.storage, _refresh),
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
                    child: const Icon(CupertinoIcons.add, color: Colors.white),
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
