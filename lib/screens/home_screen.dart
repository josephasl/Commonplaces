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
import 'entry_screen.dart'; // IMPORT NEW SCREEN
import 'manage_library_screen.dart'; // Import the new file

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ... [Storage, Controllers, Search State remain same] ...
  final StorageService _storage = StorageService();
  late PageController _pageController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _folderSort = SortOption.updatedNewest;
  String _selectedFilterCategoryId = 'ALL';
  List<AppFolder> _folders = [];
  bool _isEditing = false;
  int _selectedIndex = 1;
  Map<String, int> _folderCounts = {};

  // NAVIGATION STATE
  AppFolder? _lastOpenedFolder;
  AppEntry? _lastOpenedEntry; // NEW: Track open entry

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
    super.dispose();
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

      // If the currently open folder was deleted, close it
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
    });
  }

  void _onBottomNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // NAVIGATION FIX: If leaving the folder view, clear the folder state
    // after the animation finishes. This forces a fresh reload next time.
  }

  // OPEN FOLDER
  void _openFolder(AppFolder folder) {
    setState(() {
      _lastOpenedFolder = folder;
      _lastOpenedEntry = null; // Clear any old entry when opening a folder
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

  // NEW: OPEN ENTRY
  void _openEntry(AppEntry entry) {
    setState(() {
      _lastOpenedEntry = entry;
      // We don't need to animate page because we are likely already on Page 2
    });
  }

  // NEW: CLOSE ENTRY (Back button logic)
  void _closeEntry() {
    setState(() {
      _lastOpenedEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ManageLibraryScreen(storage: _storage, onUpdate: _refreshData),
      _buildHomeBody(),
    ];

    // LOGIC FOR 3RD TAB
    if (_lastOpenedFolder != null) {
      if (_lastOpenedEntry != null) {
        // Show Entry Screen
        pages.add(
          EntryScreen(
            entry: _lastOpenedEntry!,
            folder: _lastOpenedFolder!,
            storage: _storage,
            onBack: _closeEntry, // Go back to FolderScreen
          ),
        );
      } else {
        // Show Folder Screen
        pages.add(
          FolderScreen(
            key: ValueKey(_lastOpenedFolder!.id),
            folder: _lastOpenedFolder!,
            storage: _storage,
            onBack: () => _onBottomNavTapped(1), // Go back to Home
            onEntryTap: _openEntry, // Pass navigation callback
          ),
        );
      }
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
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
            _isEditing = false;
          });
        },
        physics: const BouncingScrollPhysics(),
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

    // 1. FILTER BY CATEGORY
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

    // 2. SEARCH
    if (_searchQuery.isNotEmpty) {
      displayFolders = displayFolders.where((f) {
        final title = f.getAttribute<String>('title') ?? '';
        return title.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 3. SORT
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

    // 4. UNTAGGED FOLDER
    AppFolder? untaggedFolder;
    bool showUntagged =
        _searchQuery.isEmpty || "untagged".contains(_searchQuery.toLowerCase());

    // Hide untagged if filtering by a specific category (except All)
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
              // CATEGORY CHIPS
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

              // GRID
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isEditing) setState(() => _isEditing = false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
                    child: MasonryGridView.count(
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

          // FLOATING BOTTOM BAR
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
          tagColorResolver: _storage.getTagColor, // Pass color resolver
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
              tagColorResolver: _storage.getTagColor, // Pass color resolver
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
