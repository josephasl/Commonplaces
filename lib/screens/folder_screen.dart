import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models.dart';
import '../storage_service.dart';
import '../cards.dart';
import '../dialogs.dart';
import '../attributes.dart';

enum EntrySortOption {
  dateCreatedNewest,
  dateCreatedOldest,
  titleAsc,
  titleDesc,
  ratingHighLow,
  ratingLowHigh,
  noteLengthAsc,
  noteLengthDesc,
}

class FolderScreen extends StatefulWidget {
  final AppFolder folder;
  final StorageService storage;
  final VoidCallback? onBack;
  final Function(AppEntry) onEntryTap;

  const FolderScreen({
    super.key,
    required this.folder,
    required this.storage,
    required this.onEntryTap,
    this.onBack,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  List<AppEntry> _allFolderEntries = [];
  Set<String> _activeTags = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  EntrySortOption _currentSort = EntrySortOption.dateCreatedNewest;

  @override
  void initState() {
    super.initState();
    if (widget.folder.id != 'untagged_special_id') {
      _activeTags = Set.from(widget.folder.displayTags);
    }
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    final List<AppEntry> entries;
    if (widget.folder.id == 'untagged_special_id') {
      entries = widget.storage.getUntaggedEntries();
    } else {
      entries = widget.storage.getEntriesForFolder(widget.folder);
    }

    if (mounted) {
      setState(() {
        _allFolderEntries = entries;
        if (widget.folder.id != 'untagged_special_id') {
          _activeTags = Set.from(widget.folder.displayTags);
        }
      });
    } else {
      _allFolderEntries = entries;
    }
  }

  void _showSortSheet() {
    final visible = widget.folder.visibleAttributes;
    final List<CupertinoActionSheetAction> actions = [];

    // 1. DATE CREATED
    actions.add(
      CupertinoActionSheetAction(
        onPressed: () {
          setState(() => _currentSort = EntrySortOption.dateCreatedNewest);
          Navigator.pop(context);
        },
        child: const Text("Date Created (Newest)"),
      ),
    );
    actions.add(
      CupertinoActionSheetAction(
        onPressed: () {
          setState(() => _currentSort = EntrySortOption.dateCreatedOldest);
          Navigator.pop(context);
        },
        child: const Text("Date Created (Oldest)"),
      ),
    );

    // 2. TITLE
    if (visible.contains('title')) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _currentSort = EntrySortOption.titleAsc);
            Navigator.pop(context);
          },
          child: const Text("Title (A-Z)"),
        ),
      );
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _currentSort = EntrySortOption.titleDesc);
            Navigator.pop(context);
          },
          child: const Text("Title (Z-A)"),
        ),
      );
    }

    // 3. RATING
    if (visible.contains('starRating')) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _currentSort = EntrySortOption.ratingHighLow);
            Navigator.pop(context);
          },
          child: const Text("Rating (High to Low)"),
        ),
      );
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _currentSort = EntrySortOption.ratingLowHigh);
            Navigator.pop(context);
          },
          child: const Text("Rating (Low to High)"),
        ),
      );
    }

    // 4. NOTES
    if (visible.contains('notes')) {
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _currentSort = EntrySortOption.noteLengthDesc);
            Navigator.pop(context);
          },
          child: const Text("Note Length (Longest)"),
        ),
      );
      actions.add(
        CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _currentSort = EntrySortOption.noteLengthAsc);
            Navigator.pop(context);
          },
          child: const Text("Note Length (Shortest)"),
        ),
      );
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("Sort Entries By"),
        actions: actions,
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
    // 1. FILTER
    List<AppEntry> processedEntries = [];
    final customAttrs = widget.storage.getCustomAttributes();
    final registry = getAttributeRegistry(customAttrs);

    if (widget.folder.id == 'untagged_special_id') {
      processedEntries = List.from(_allFolderEntries);
    } else {
      // Only show entries that have at least one tag in _activeTags
      processedEntries = _allFolderEntries.where((entry) {
        final rawTag = entry.getAttribute('tag');
        if (rawTag == null) return false;

        List<String> entryTags = [];
        if (rawTag is String)
          entryTags = [rawTag];
        else if (rawTag is List)
          entryTags = List<String>.from(rawTag);

        if (_activeTags.isEmpty) return false;
        return entryTags.any((t) => _activeTags.contains(t));
      }).toList();
    }

    // 2. SEARCH
    if (_searchQuery.isNotEmpty) {
      processedEntries = processedEntries.where((entry) {
        final title = (entry.getAttribute('title') ?? '').toString();
        final notes = (entry.getAttribute('notes') ?? '').toString();
        final query = _searchQuery.toLowerCase();
        return title.toLowerCase().contains(query) ||
            notes.toLowerCase().contains(query);
      }).toList();
    }

    // 3. SORT
    processedEntries.sort((a, b) {
      switch (_currentSort) {
        case EntrySortOption.dateCreatedNewest:
          final da =
              DateTime.tryParse(
                a.getAttribute('dateCreated')?.toString() ?? '',
              ) ??
              DateTime(2000);
          final db =
              DateTime.tryParse(
                b.getAttribute('dateCreated')?.toString() ?? '',
              ) ??
              DateTime(2000);
          return db.compareTo(da);
        case EntrySortOption.dateCreatedOldest:
          final da =
              DateTime.tryParse(
                a.getAttribute('dateCreated')?.toString() ?? '',
              ) ??
              DateTime(2000);
          final db =
              DateTime.tryParse(
                b.getAttribute('dateCreated')?.toString() ?? '',
              ) ??
              DateTime(2000);
          return da.compareTo(db);
        case EntrySortOption.titleAsc:
          return (a.getAttribute('title') ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (b.getAttribute('title') ?? '').toString().toLowerCase(),
              );
        case EntrySortOption.titleDesc:
          return (b.getAttribute('title') ?? '')
              .toString()
              .toLowerCase()
              .compareTo(
                (a.getAttribute('title') ?? '').toString().toLowerCase(),
              );
        case EntrySortOption.ratingHighLow:
          final ra = (a.getAttribute('starRating') ?? 0) as int;
          final rb = (b.getAttribute('starRating') ?? 0) as int;
          return rb.compareTo(ra);
        case EntrySortOption.ratingLowHigh:
          final ra = (a.getAttribute('starRating') ?? 0) as int;
          final rb = (b.getAttribute('starRating') ?? 0) as int;
          return ra.compareTo(rb);
        case EntrySortOption.noteLengthAsc:
          final na = (a.getAttribute('notes') ?? '').toString().length;
          final nb = (b.getAttribute('notes') ?? '').toString().length;
          return na.compareTo(nb);
        case EntrySortOption.noteLengthDesc:
          final na = (a.getAttribute('notes') ?? '').toString().length;
          final nb = (b.getAttribute('notes') ?? '').toString().length;
          return nb.compareTo(na);
      }
    });

    final visibleAttrs = widget.folder.visibleAttributes;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.folder.getAttribute<String>('title') ?? "Folder",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.black),
          onPressed: () {
            if (widget.onBack != null)
              widget.onBack!();
            else
              Navigator.of(context).pop();
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
        actions: [
          // --- UPDATED ACTIONS: Only one button now ---
          if (widget.folder.id != 'untagged_special_id')
            IconButton(
              icon: const Icon(
                CupertinoIcons.pencil,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => showEditFolderDialog(
                context,
                widget.folder,
                widget.storage,
                _refresh,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // TAG FILTER BAR
              if (widget.folder.displayTags.isNotEmpty)
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.folder.displayTags.length,
                    separatorBuilder: (c, i) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final tag = widget.folder.displayTags[index];
                      final isActive = _activeTags.contains(tag);
                      // Safe Color Lookup
                      final catColor = widget.storage.getTagColor(tag);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isActive)
                              _activeTags.remove(tag);
                            else
                              _activeTags.add(tag);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? catColor.withOpacity(0.2)
                                : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(16),
                            border: isActive
                                ? Border.all(color: catColor)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "#$tag",
                            style: TextStyle(
                              color: catColor,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // GRID
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
                  child: processedEntries.isEmpty
                      ? const Center(
                          child: Text(
                            "No entries found",
                            style: TextStyle(color: CupertinoColors.systemGrey),
                          ),
                        )
                      : MasonryGridView.count(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          itemCount: processedEntries.length,
                          itemBuilder: (context, index) {
                            final entry = processedEntries[index];
                            return GestureDetector(
                              onTap: () =>
                                  widget.onEntryTap(entry), // TRIGGER CALLBACK
                              child: EntryCard(
                                entry: entry,
                                visibleAttributes: visibleAttrs,
                                tagColorResolver: widget.storage.getTagColor,
                                registry: registry,
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),

          // FLOATING BAR
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
                        hintText: "Search...",
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
                GestureDetector(
                  onTap: () async {
                    List<String>? prefillTags;
                    if (widget.folder.displayTags.isNotEmpty)
                      prefillTags = List.from(widget.folder.displayTags);
                    await showAddEntryDialog(
                      context,
                      widget.storage,
                      _refresh,
                      prefillTags: prefillTags,
                      restrictToAttributes: widget.folder.visibleAttributes,
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
