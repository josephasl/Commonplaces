import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../storage_service.dart';
import '../attributes.dart';
import '../models.dart';
import '../dialogs.dart';
import 'edit_tags_screen.dart';

// --- NEW: Sort Options Enum ---
enum AttributeSortOption { nameAsc, nameDesc, dateNewest, dateOldest }

class ManageLibraryScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;

  const ManageLibraryScreen({super.key, required this.storage, this.onUpdate});

  @override
  State<ManageLibraryScreen> createState() => ManageLibraryScreenState();
}

// Public state class for GlobalKey access
class ManageLibraryScreenState extends State<ManageLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. Keys and Controllers
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
    _attributesScrollController.dispose(); // Dispose local controller
    super.dispose();
  }

  // Handle Nav Bar Tap
  void handleNavTap() {
    if (_tabController.index == 0) {
      // Tab 0: Edit Tags -> Call child's method via Key
      _editTagsKey.currentState?.scrollToTop();
    } else {
      // Tab 1: Attributes -> Use local controller
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
        actions: [
          if (_tabController.index == 0)
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
                  dividerHeight: 0,
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
                  indicatorPadding: const EdgeInsets.all(2),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: '.SF Pro Text',
                  ),
                  tabs: const [
                    Tab(text: "Group Tags"),
                    Tab(text: "Custom Attributes"),
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
          // TAB 1: Edit Tags
          EditTagsScreen(
            key: _editTagsKey,
            storage: widget.storage,
            onUpdate: widget.onUpdate,
          ),

          // TAB 2: Attributes Manager
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
  // --- NEW: Sort State ---
  AttributeSortOption _currentSort = AttributeSortOption.dateNewest;

  void _refresh() {
    setState(() {});
    widget.onUpdate?.call();
  }

  // --- NEW: Helper to extract timestamp from key (label_timestamp) ---
  int _getTimestamp(String key) {
    try {
      final parts = key.split('_');
      if (parts.length > 1) {
        return int.parse(parts.last);
      }
    } catch (_) {}
    return 0;
  }

  // --- NEW: Sort Sheet Dialog ---
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
    final customAttrs = widget.storage.getCustomAttributes();

    // --- NEW: Apply Sorting ---
    customAttrs.sort((a, b) {
      switch (_currentSort) {
        case AttributeSortOption.nameAsc:
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        case AttributeSortOption.nameDesc:
          return b.label.toLowerCase().compareTo(a.label.toLowerCase());
        case AttributeSortOption.dateNewest:
          return _getTimestamp(b.key).compareTo(_getTimestamp(a.key));
        case AttributeSortOption.dateOldest:
          return _getTimestamp(a.key).compareTo(_getTimestamp(b.key));
      }
    });

    return Container(
      color: const Color(0xFFF2F2F7), // iOS Grouped Background
      child: Stack(
        children: [
          ListView(
            controller: widget.scrollController,
            key: const PageStorageKey('attributes_list'),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: const [
                    SizedBox(width: 8),
                    Text(
                      "Custom Attributes",
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGrey,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // --- LIST CONTAINER ---
              if (customAttrs.isEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.slider_horizontal_3,
                        size: 40,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "No custom attributes",
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Add fields like 'Author' or 'Pages'",
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: List.generate(customAttrs.length, (index) {
                      final attr = customAttrs[index];
                      final isLast = index == customAttrs.length - 1;

                      return Column(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                showAttributeOptionsDialog(
                                  context,
                                  widget.storage,
                                  attr,
                                  _refresh,
                                );
                              },
                              borderRadius: isLast
                                  ? const BorderRadius.vertical(
                                      bottom: Radius.circular(10),
                                    )
                                  : (index == 0
                                        ? const BorderRadius.vertical(
                                            top: Radius.circular(10),
                                          )
                                        : BorderRadius.zero),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            attr.label,
                                            style: const TextStyle(
                                              fontFamily: '.SF Pro Text',
                                              fontSize: 16,
                                              color: Colors.black,
                                              fontWeight: FontWeight.normal,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            attr.type.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontFamily: '.SF Pro Text',
                                              fontSize: 11,
                                              color: CupertinoColors.systemGrey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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

          // --- FLOATING ACTION BUTTONS (Sort + Add) ---
          Positioned(
            bottom: 20,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min, // Keep tight
              children: [
                // 1. Sort Button
                GestureDetector(
                  onTap: _showSortSheet,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.sort_down,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 2. Add Button
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
