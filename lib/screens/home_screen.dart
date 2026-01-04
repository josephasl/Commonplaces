import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../storage_service.dart';
import '../../models.dart';
import '../dialogs.dart';
import '../cards.dart';
import 'folder_screen.dart';
import '../shakeable.dart';
import 'entry_screen.dart';
import 'manage_library_screen.dart';
import '../ui/app_styles.dart';
import '../ui/dialogs/sort_bottom_sheet.dart';
import '../ui/widgets/common_ui.dart';

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
  final ScrollController _categoryScrollController = ScrollController();

  final GlobalKey<ManageLibraryScreenState> _manageLibKey = GlobalKey();
  GlobalKey<FolderScreenState> _folderScreenKey = GlobalKey();
  final GlobalKey<NavigatorState> _folderNavigatorKey = GlobalKey();

  ScrollPhysics _pagePhysics = const BouncingScrollPhysics();

  String _searchQuery = '';
  String _folderSortKey = 'lastAddedTo';
  bool _folderSortAsc = false;
  String _selectedFilterCategoryId = 'ALL';

  List<AppFolder> _folders = [];
  bool _isEditing = false;
  int _selectedIndex = 1;
  Map<String, int> _folderCounts = {};
  AppFolder? _lastOpenedFolder;

  final Map<String, int> _randomSortValues = {};

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
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _setPageSwipeEnabled(bool enabled) {
    final newPhysics = enabled
        ? const BouncingScrollPhysics()
        : const NeverScrollableScrollPhysics();
    if (_pagePhysics.runtimeType != newPhysics.runtimeType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pagePhysics = newPhysics);
      });
    }
  }

  void _regenerateRandomValues() {
    final rng = math.Random();
    _randomSortValues.clear();
    for (var f in _folders) {
      _randomSortValues[f.id] = rng.nextInt(100000000);
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

      if (_folderSortKey == 'random') {
        _regenerateRandomValues();
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

  void _showFolderSortSheet() async {
    final options = [
      const SortOptionItem('lastAddedTo', 'Last Added'),
      const SortOptionItem('dateCreated', 'Date Created'),
      const SortOptionItem('title', 'Name'),
      const SortOptionItem('count', 'Entry Count'),
      const SortOptionItem('random', 'Random'),
    ];

    final result = await showUnifiedSortSheet(
      context: context,
      title: "Sort Folders By",
      options: options,
      currentSortKey: _folderSortKey,
      currentIsAscending: _folderSortAsc,
    );

    if (result != null && mounted) {
      setState(() {
        if (result.key == 'random') {
          _folderSortKey = 'random';
          _folderSortAsc = true;
          _regenerateRandomValues();
        } else {
          _folderSortKey = result.key;
          _folderSortAsc = result.isAscending;
        }
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
      _isEditing = false; // Stop editing on Home Screen

      // Stop editing on Folder Screen if we leave the folder tab
      if (index != 2) {
        _folderScreenKey.currentState?.stopEditing();
      }

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
            setState(() => _selectedFilterCategoryId = 'ALL');
          }
          if (_categoryScrollController.hasClients &&
              _categoryScrollController.offset > 0) {
            _categoryScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
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
      // If we are leaving the Folder Tab (2), stop editing immediately
      if (_selectedIndex == 2 && index != 2) {
        _folderScreenKey.currentState?.stopEditing();
      }

      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openFolder(AppFolder folder) {
    setState(() {
      if (_lastOpenedFolder?.id != folder.id) {
        _folderScreenKey = GlobalKey();
      }
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
      int result = 0;

      switch (_folderSortKey) {
        case 'title':
          result = (a.getAttribute('title') ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b.getAttribute('title') ?? '').toString().toLowerCase(),
              );
          break;

        case 'dateCreated':
          final da =
              DateTime.tryParse(a.getAttribute('dateCreated') ?? '') ??
              DateTime(2000);
          final db =
              DateTime.tryParse(b.getAttribute('dateCreated') ?? '') ??
              DateTime(2000);
          result = da.compareTo(db);
          break;

        case 'lastAddedTo':
          final da =
              DateTime.tryParse(a.getAttribute('lastAddedTo') ?? '') ??
              DateTime(2000);
          final db =
              DateTime.tryParse(b.getAttribute('lastAddedTo') ?? '') ??
              DateTime(2000);
          result = da.compareTo(db);
          break;

        case 'count':
          final countA = _folderCounts[a.id] ?? 0;
          final countB = _folderCounts[b.id] ?? 0;
          result = countA.compareTo(countB);
          break;

        case 'random':
          final rA = _randomSortValues[a.id] ?? 0;
          final rB = _randomSortValues[b.id] ?? 0;
          result = rA.compareTo(rB);
          break;
      }

      return _folderSortAsc ? result : -result;
    });

    AppFolder? untaggedFolder;
    bool showUntagged =
        _searchQuery.isEmpty || "untagged".contains(_searchQuery.toLowerCase());
    if (_selectedFilterCategoryId != 'ALL') showUntagged = false;

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
      backgroundColor: AppColors.coloredBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
        title: Text("Commonplaces", style: AppTextStyles.header),
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
          GestureDetector(
            onTap: () {
              if (_isEditing) setState(() => _isEditing = false);
            },
            child: MasonryGridView.count(
              controller: _homeScrollController,
              key: const PageStorageKey('home_grid'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              // Top padding (68) allows content to start below tags but scroll behind them
              padding: const EdgeInsets.fromLTRB(8, 68, 8, 100),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ShaderMask(
              shaderCallback: AppShaders.maskFadeRight,
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    _buildFilterChip(
                      'ALL',
                      'All',
                      Colors.black,
                      Icons.grid_view,
                    ),
                    ...categories
                        .map(
                          (cat) => _buildFilterChip(
                            cat.id,
                            cat.name,
                            AppConstants.categoryColors[cat.colorIndex],
                            AppConstants.categoryIcons[cat.iconIndex],
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),
            ),
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
                    hintText: "Search folders...",
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
                  icon: CupertinoIcons.sort_down,
                  onTap: _showFolderSortSheet,
                ),
                const SizedBox(width: AppDimens.spacingM),
                AppFloatingButton(
                  icon: CupertinoIcons.add,
                  color: AppColors.primary,
                  iconColor: Colors.white,
                  onTap: () async {
                    await showAddEntryDialog(context, _storage, _refreshData);
                    _refreshData();
                  },
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
    final bgColor = isSelected ? color : AppColors.background;
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
    final coverImage = _storage.getFolderCoverImage(folder);

    if (isUntaggedFolder) {
      return GestureDetector(
        onTap: () => _openFolder(folder),
        child: FolderCard(
          folder: folder,
          color: AppColors.untaggedBackground,
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
      child: ShakeableWithDelete(
        enabled: _isEditing,
        onDelete: () => _deleteFolder(folder),
        child: FolderCard(
          folder: folder,
          entryCount: count,
          tagColorResolver: _storage.getTagColor,
          coverImageUrl: coverImage,
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
        return AppPageRoute(
          builder: (context) => FolderScreen(
            key: widget.folderScreenKey,
            folder: widget.folder,
            storage: widget.storage,
            onBack: widget.onBack,
            onEntryTap: (entries, index) {
              Navigator.of(context)
                  .push(
                    AppPageRoute(
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null) {
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
