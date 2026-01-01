import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../storage_service.dart';
import '../models.dart';
import '../dialogs.dart';
import '../cards.dart';
import 'folder_screen.dart';
import '../shakeable.dart';
import 'edit_tags_screen.dart';
import 'entry_screen.dart';
import 'manage_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();

  final ScrollController _homeScrollController = ScrollController();

  // GlobalKeys
  final GlobalKey<ManageLibraryScreenState> _manageLibKey = GlobalKey();
  final GlobalKey<FolderScreenState> _folderScreenKey = GlobalKey();
  final GlobalKey<NavigatorState> _folderNavigatorKey = GlobalKey();

  ScrollPhysics _pagePhysics = const BouncingScrollPhysics();

  String _searchQuery = '';
  SortOption _folderSort = SortOption.updatedNewest;
  String _selectedFilterCategoryId = 'ALL';
  List<AppFolder> _folders = [];
  bool _isEditing = false;
  int _selectedIndex = 1;
  Map<String, int> _folderCounts = {};

  AppFolder? _lastOpenedFolder;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _refreshData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _homeScrollController.dispose();
    super.dispose();
  }

  void _setPageSwipeEnabled(bool enabled) {
    final newPhysics = enabled
        ? const BouncingScrollPhysics()
        : const NeverScrollableScrollPhysics();

    if (_pagePhysics.runtimeType != newPhysics.runtimeType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pagePhysics = newPhysics;
          });
        }
      });
    }
  }

  void _refreshData() {
    setState(() {
      _folders = _storage.getAllFolders();
      _folderCounts.clear();
      final allEntries = _storage.getAllEntries();
      final untaggedEntries = _storage.getUntaggedEntries();
      _folderCounts['untagged_special_id'] = untaggedEntries.length;

      for (var folder in _folders) {
        int count = 0;
        if (folder.displayTags.isNotEmpty) {
          count = allEntries.where((entry) {
            final rawTag = entry.getAttribute('tag');
            if (rawTag == null) return false;
            List<String> entryTags = [];
            if (rawTag is String) {
              if (rawTag.isNotEmpty) entryTags = [rawTag];
            } else if (rawTag is List) {
              entryTags = rawTag.map((e) => e.toString()).toList();
            }
            return entryTags.any((t) => folder.displayTags.contains(t));
          }).length;
        }
        _folderCounts[folder.id] = count;
      }

      if (_lastOpenedFolder != null) {
        final exists =
            _folders.any((f) => f.id == _lastOpenedFolder!.id) ||
            _lastOpenedFolder!.id == 'untagged_special_id';
        if (!exists) {
          _lastOpenedFolder = null;
          if (_selectedIndex == 2) {
            _selectedIndex = 1;
            _pageController.jumpToPage(1);
          }
        }
      }
    });
  }

  void _deleteFolder(AppFolder folder) {
    showDeleteConfirmationDialog(
      context: context,
      title: "Delete Folder?",
      message: "Delete '${folder.getAttribute('title')}'?",
      subtitle: "This will delete the folder but NOT the entries inside it.",
      onConfirm: () async {
        await _storage.deleteFolder(folder.id);
        _refreshData();
      },
    );
  }

  void _showFolderSortSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("Sort Folders By"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _folderSort = SortOption.updatedNewest);
              Navigator.pop(ctx);
            },
            child: const Text("Last Used (Newest)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _folderSort = SortOption.createdNewest);
              Navigator.pop(ctx);
            },
            child: const Text("Date Created (Newest)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _folderSort = SortOption.nameAsc);
              Navigator.pop(ctx);
            },
            child: const Text("Name (A-Z)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _folderSort = SortOption.countHighToLow);
              Navigator.pop(ctx);
            },
            child: const Text("Entry Count (High to Low)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _folderSort = SortOption.countLowToHigh);
              Navigator.pop(ctx);
            },
            child: const Text("Entry Count (Low to High)"),
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

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
      _isEditing = false;
      if (index != 2) _pagePhysics = const BouncingScrollPhysics();
    });
  }

  void _onBottomNavTapped(int index) {
    if (_selectedIndex == index) {
      if (index == 0) {
        _manageLibKey.currentState?.handleNavTap();
      } else if (index == 1) {
        if (_homeScrollController.hasClients &&
            _homeScrollController.offset > 0) {
          _homeScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          if (_selectedFilterCategoryId != 'ALL') {
            setState(() {
              _selectedFilterCategoryId = 'ALL';
            });
          }
        }
      } else if (index == 2) {
        if (_folderNavigatorKey.currentState?.canPop() ?? false) {
          _folderNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        } else {
          _folderScreenKey.currentState?.handleNavTap();
        }
      }
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openFolder(AppFolder folder) {
    setState(() {
      _lastOpenedFolder = folder;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ManageLibraryScreen(
        key: _manageLibKey,
        storage: _storage,
        onUpdate: _refreshData,
      ),
      _buildHomeBody(),
    ];

    if (_lastOpenedFolder != null) {
      pages.add(
        FolderTab(
          key: ValueKey(_lastOpenedFolder!.id),
          folder: _lastOpenedFolder!,
          storage: _storage,
          navigatorKey: _folderNavigatorKey,
          folderScreenKey: _folderScreenKey,
          onBack: () => _onBottomNavTapped(1),
          onDataChanged: _refreshData,
          onStackChanged: (isAtRoot) => _setPageSwipeEnabled(isAtRoot),
        ),
      );
    }

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.number),
        activeIcon: Icon(CupertinoIcons.number),
        label: "Tags",
      ),
      const BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.home),
        activeIcon: Icon(CupertinoIcons.house_fill),
        label: "Home",
      ),
    ];

    if (_lastOpenedFolder != null) {
      navItems.add(
        const BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.square),
          activeIcon: Icon(CupertinoIcons.square_fill),
          label: "Folder",
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: _pagePhysics,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1.0),
          ),
        ),
        child: Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onBottomNavTapped,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: CupertinoColors.activeBlue,
            unselectedItemColor: CupertinoColors.systemGrey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            type: BottomNavigationBarType.fixed,
            items: navItems,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    List<AppFolder> displayFolders = List.from(_folders);

    if (_selectedFilterCategoryId != 'ALL') {
      final mapping = _storage.getTagMapping();
      displayFolders = displayFolders.where((f) {
        if (f.displayTags.isEmpty) return false;
        return f.displayTags.any((t) {
          final catId = mapping[t] ?? 'default_grey_cat';
          return catId == _selectedFilterCategoryId;
        });
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      displayFolders = displayFolders.where((f) {
        final title = f.getAttribute<String>('title') ?? '';
        return title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    displayFolders.sort((a, b) {
      switch (_folderSort) {
        case SortOption.nameAsc:
          return (a.getAttribute('title') ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b.getAttribute('title') ?? '').toString().toLowerCase(),
              );
        case SortOption.nameDesc:
          return (b.getAttribute('title') ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (a.getAttribute('title') ?? '').toString().toLowerCase(),
              );
        case SortOption.createdNewest:
          final da =
              DateTime.tryParse(a.getAttribute('dateCreated') ?? '') ??
              DateTime(2000);
          final db =
              DateTime.tryParse(b.getAttribute('dateCreated') ?? '') ??
              DateTime(2000);
          return db.compareTo(da);
        case SortOption.updatedNewest:
          final da =
              DateTime.tryParse(a.getAttribute('lastAddedTo') ?? '') ??
              DateTime(2000);
          final db =
              DateTime.tryParse(b.getAttribute('lastAddedTo') ?? '') ??
              DateTime(2000);
          return db.compareTo(da);
        case SortOption.countHighToLow:
          return (_folderCounts[b.id] ?? 0).compareTo(_folderCounts[a.id] ?? 0);
        case SortOption.countLowToHigh:
          return (_folderCounts[a.id] ?? 0).compareTo(_folderCounts[b.id] ?? 0);
        default:
          return 0;
      }
    });

    AppFolder? untaggedFolder;
    bool showUntagged =
        _searchQuery.isEmpty || "untagged".contains(_searchQuery.toLowerCase());
    if (_selectedFilterCategoryId != 'ALL') {
      showUntagged = false;
    }

    if (showUntagged) {
      untaggedFolder = AppFolder(
        id: 'untagged_special_id',
        attributes: {
          'title': 'Untagged',
          'displayTags': <String>[],
          'visibleAttributes': ['title', 'notes', 'dateCompleted'],
        },
      );
    }

    final List<AppFolder> allItems = [
      ...displayFolders,
      if (untaggedFolder != null) untaggedFolder,
    ];

    final categories = _storage.getTagCategories();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
        title: const Text(
          "My Library",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_isEditing)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                "Done",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => setState(() => _isEditing = false),
            )
          else
            IconButton(
              icon: const Icon(
                CupertinoIcons.folder_badge_plus,
                color: Colors.black,
              ),
              tooltip: "Add Folder",
              onPressed: () =>
                  showAddFolderDialog(context, _storage, _refreshData),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      'ALL',
                      'All',
                      Colors.black,
                      Icons.grid_view,
                    ),
                    ...categories.map((cat) {
                      return _buildFilterChip(
                        cat.id,
                        cat.name,
                        AppConstants.categoryColors[cat.colorIndex],
                        AppConstants.categoryIcons[cat.iconIndex],
                      );
                    }).toList(),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isEditing) setState(() => _isEditing = false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
                    child: MasonryGridView.count(
                      controller: _homeScrollController,
                      key: const PageStorageKey('home_grid'),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      itemCount: allItems.length,
                      itemBuilder: (context, index) {
                        final item = allItems[index];
                        return _buildFolderItem(item);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                        hintText: "Search folders...",
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
                  onTap: _showFolderSortSheet,
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
                GestureDetector(
                  onTap: () async {
                    await showAddEntryDialog(context, _storage, _refreshData);
                    _refreshData();
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

  Widget _buildFilterChip(String id, String label, Color color, IconData icon) {
    final isSelected = _selectedFilterCategoryId == id;
    final bgColor = isSelected ? color : Colors.grey.shade100;
    final textColor = isSelected ? Colors.white : Colors.grey.shade800;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilterCategoryId = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem(AppFolder folder) {
    final count = _folderCounts[folder.id] ?? 0;
    final isUntaggedFolder = folder.id == 'untagged_special_id';

    if (isUntaggedFolder) {
      return GestureDetector(
        onTap: () => _openFolder(folder),
        child: FolderCard(
          folder: folder,
          color: const Color(0xFFF2F2F7),
          entryCount: count,
          tagColorResolver: _storage.getTagColor,
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => setState(() => _isEditing = true),
      onTap: () {
        if (_isEditing)
          setState(() => _isEditing = false);
        else
          _openFolder(folder);
      },
      child: Shakeable(
        enabled: _isEditing,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            FolderCard(
              folder: folder,
              entryCount: count,
              tagColorResolver: _storage.getTagColor,
            ),
            if (_isEditing)
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: () => _deleteFolder(folder),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E8E93),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- FOLDER TAB & OBSERVER ---
class FolderTab extends StatefulWidget {
  final AppFolder folder;
  final StorageService storage;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<FolderScreenState> folderScreenKey;
  final VoidCallback onBack;
  final VoidCallback onDataChanged;
  final Function(bool isAtRoot) onStackChanged;

  const FolderTab({
    super.key,
    required this.folder,
    required this.storage,
    required this.navigatorKey,
    required this.folderScreenKey,
    required this.onBack,
    required this.onDataChanged,
    required this.onStackChanged,
  });

  @override
  State<FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends State<FolderTab>
    with AutomaticKeepAliveClientMixin {
  late _FolderNavObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = _FolderNavObserver(
      onStackChanged: (isAtRoot) {
        widget.onStackChanged(isAtRoot);
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Navigator(
      key: widget.navigatorKey,
      observers: [_observer],
      onGenerateRoute: (settings) {
        return CupertinoPageRoute(
          builder: (context) => FolderScreen(
            key: widget.folderScreenKey,
            folder: widget.folder,
            storage: widget.storage,
            onBack: widget.onBack,
            onEntryTap: (entries, index) {
              Navigator.of(context)
                  .push(
                    CupertinoPageRoute(
                      builder: (context) => EntryScreen(
                        entries: entries,
                        initialIndex: index,
                        folder: widget.folder,
                        storage: widget.storage,
                        onEntryChanged: (entry) {
                          widget.folderScreenKey.currentState
                              ?.updateLastViewedEntry(entry.id);
                        },
                      ),
                    ),
                  )
                  .then((_) {
                    widget.onDataChanged();
                    widget.folderScreenKey.currentState?.refresh();
                  });
            },
          ),
        );
      },
    );
  }
}

class _FolderNavObserver extends NavigatorObserver {
  final Function(bool isAtRoot) onStackChanged;

  _FolderNavObserver({required this.onStackChanged});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // FIX: Check if we actually pushed deep or if this is the initial route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null) {
        // If canPop is true, we have a stack (Entry Screen).
        // If false, we are at root (Folder Screen).
        final isAtRoot = !navigator!.canPop();
        onStackChanged(isAtRoot);
      }
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null) {
        final isAtRoot = !navigator!.canPop();
        onStackChanged(isAtRoot);
      }
    });
  }
}
