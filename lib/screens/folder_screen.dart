import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models.dart';
import '../storage_service.dart';
import '../cards.dart';
import '../dialogs.dart';
import '../attributes.dart';

class FolderScreen extends StatefulWidget {
  final AppFolder folder;
  final StorageService storage;
  final VoidCallback? onBack;
  final Function(List<AppEntry> entries, int index) onEntryTap;

  const FolderScreen({
    super.key,
    required this.folder,
    required this.storage,
    required this.onEntryTap,
    this.onBack,
  });

  @override
  State<FolderScreen> createState() => FolderScreenState();
}

class FolderScreenState extends State<FolderScreen> {
  List<AppEntry> _allFolderEntries = [];
  Set<String> _activeTags = {};

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _tagScrollController = ScrollController();

  String _searchQuery = '';

  // --- SORTING STATE ---
  String _sortAttributeKey = 'dateCreated';
  bool _isAscending = false;

  String? _lastViewedEntryId;
  Offset _dragStart = Offset.zero;

  void updateLastViewedEntry(String id) {
    _lastViewedEntryId = id;
  }

  @override
  void initState() {
    super.initState();
    if (widget.folder.id != 'untagged_special_id') {
      _activeTags = Set.from(widget.folder.displayTags);
    }
    // Set default sort
    if (!widget.folder.visibleAttributes.contains('dateCreated') &&
        widget.folder.visibleAttributes.isNotEmpty) {
      _sortAttributeKey = widget.folder.visibleAttributes.first;
      _isAscending = true;
    }
    refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tagScrollController.dispose();
    super.dispose();
  }

  void handleNavTap() {
    if (!mounted) return;
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (widget.folder.id != 'untagged_special_id') {
      if (_activeTags.length < widget.folder.displayTags.length) {
        setState(() {
          _activeTags = Set.from(widget.folder.displayTags);
        });
      }
      if (_tagScrollController.hasClients && _tagScrollController.offset > 0) {
        _tagScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void refresh() {
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
          final currentTags = widget.folder.displayTags;
          _activeTags = _activeTags.intersection(currentTags.toSet());
          if (_activeTags.isEmpty && currentTags.isNotEmpty) {
            _activeTags = currentTags.toSet();
          }
        }
      });
    } else {
      _allFolderEntries = entries;
    }
  }

  // --- REFACTORED SORT LOGIC (Async Pattern) ---
  Future<void> _showSortSheet() async {
    final customAttrs = widget.storage.getCustomAttributes();
    final registry = getAttributeRegistry(customAttrs);

    final List<String> sortableKeys = List.from(
      widget.folder.visibleAttributes,
    );

    // 1. AWAIT the user's selection
    final String? selectedKey = await showCupertinoModalPopup<String>(
      context: context,
      // Use 'ctx' for the dialog context to ensure we pop ONLY the dialog
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("Sort Entries By"),
        message: const Text("Tap again to toggle order"),
        actions: sortableKeys.map((key) {
          final def = registry[key];
          // Use 'Container()' or exclude via where() if null to avoid crash
          if (def == null) return Container();

          final isSelected = _sortAttributeKey == key;
          String label = def.label;

          IconData? icon;
          if (isSelected) {
            icon = _isAscending
                ? CupertinoIcons.arrow_up
                : CupertinoIcons.arrow_down;
          }

          return CupertinoActionSheetAction(
            onPressed: () {
              // 2. Return the KEY, do not setState here
              Navigator.of(ctx).pop(key);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 16, color: CupertinoColors.activeBlue),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text("Cancel"),
        ),
      ),
    );

    // 3. If nothing selected or widget closed, stop
    if (selectedKey == null || !mounted) return;

    // 4. Update State safely AFTER dialog is closed
    setState(() {
      final def = registry[selectedKey];

      if (_sortAttributeKey == selectedKey) {
        // Same key = Toggle direction
        _isAscending = !_isAscending;
      } else {
        // New key = Select key
        _sortAttributeKey = selectedKey;

        // Set Default Direction based on Type
        if (def?.type == AttributeValueType.date ||
            def?.type == AttributeValueType.number ||
            def?.type == AttributeValueType.rating ||
            def?.type == AttributeValueType.image) {
          _isAscending = false;
        } else {
          _isAscending = true;
        }
      }
    });
  }

  void _openLastViewedEntry(List<AppEntry> currentList) {
    if (_lastViewedEntryId == null) return;
    final index = currentList.indexWhere((e) => e.id == _lastViewedEntryId);
    if (index != -1) {
      widget.onEntryTap(currentList, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<AppEntry> processedEntries = [];
    final customAttrs = widget.storage.getCustomAttributes();
    final registry = getAttributeRegistry(customAttrs);

    if (widget.folder.id == 'untagged_special_id') {
      processedEntries = List.from(_allFolderEntries);
    } else {
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

    if (_searchQuery.isNotEmpty) {
      processedEntries = processedEntries.where((entry) {
        final title = (entry.getAttribute('title') ?? '').toString();
        final searchStr = entry.attributes.values.join(' ').toLowerCase();
        return searchStr.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // --- SORT IMPLEMENTATION ---
    processedEntries.sort((a, b) {
      final def = registry[_sortAttributeKey];

      dynamic valA = a.getAttribute(_sortAttributeKey);
      dynamic valB = b.getAttribute(_sortAttributeKey);

      int result = 0;

      // Handle nulls first to avoid crashes
      if (valA == null && valB == null) return 0;
      if (valA == null) return _isAscending ? -1 : 1;
      if (valB == null) return _isAscending ? 1 : -1;

      if (def?.type == AttributeValueType.image) {
        final hasA = (valA.toString().isNotEmpty) ? 1 : 0;
        final hasB = (valB.toString().isNotEmpty) ? 1 : 0;
        result = hasA.compareTo(hasB);
      } else if (def?.type == AttributeValueType.number ||
          def?.type == AttributeValueType.rating) {
        final numA = num.tryParse(valA.toString()) ?? 0;
        final numB = num.tryParse(valB.toString()) ?? 0;
        result = numA.compareTo(numB);
      } else if (def?.type == AttributeValueType.date) {
        final dateA = DateTime.tryParse(valA.toString()) ?? DateTime(2000);
        final dateB = DateTime.tryParse(valB.toString()) ?? DateTime(2000);
        result = dateA.compareTo(dateB);
      } else {
        result = valA.toString().toLowerCase().compareTo(
          valB.toString().toLowerCase(),
        );
      }

      return _isAscending ? result : -result;
    });

    final visibleAttrs = widget.folder.visibleAttributes;

    return Listener(
      onPointerDown: (event) {
        _dragStart = event.position;
      },
      onPointerUp: (event) {
        final delta = event.position - _dragStart;
        if (delta.dx < -50 && delta.dy.abs() < 50) {
          _openLastViewedEntry(processedEntries);
        }
      },
      child: Scaffold(
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: Colors.grey.shade200, height: 1.0),
          ),
          actions: [
            if (widget.folder.id != 'untagged_special_id')
              IconButton(
                icon: const Icon(
                  CupertinoIcons.ellipsis,
                  color: Colors.black,
                  size: 20,
                ),
                onPressed: () async {
                  final previousTags = Set<String>.from(
                    widget.folder.displayTags,
                  );
                  await showEditFolderDialog(
                    context,
                    widget.folder,
                    widget.storage,
                    refresh,
                  );
                  final currentTags = widget.folder.displayTags;
                  final addedTags = currentTags.where(
                    (t) => !previousTags.contains(t),
                  );
                  if (addedTags.isNotEmpty && mounted) {
                    setState(() {
                      _activeTags.addAll(addedTags);
                    });
                  }
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (widget.folder.displayTags.isNotEmpty)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.separated(
                      controller: _tagScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.folder.displayTags.length,
                      separatorBuilder: (c, i) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tag = widget.folder.displayTags[index];
                        final isActive = _activeTags.contains(tag);
                        final catColor = widget.storage.getTagColor(tag);

                        return GestureDetector(
                          onTap: () {
                            if (!mounted) return;
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

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
                    child: processedEntries.isEmpty
                        ? const Center(
                            child: Text(
                              "No entries found",
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          )
                        : MasonryGridView.count(
                            controller: _scrollController,
                            key: PageStorageKey(
                              'folder_grid_${widget.folder.id}',
                            ),
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
                                onTap: () {
                                  updateLastViewedEntry(entry.id);
                                  widget.onEntryTap(processedEntries, index);
                                },
                                child: Hero(
                                  tag: 'entry_hero_${entry.id}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: EntryCard(
                                      entry: entry,
                                      visibleAttributes: visibleAttrs,
                                      tagColorResolver:
                                          widget.storage.getTagColor,
                                      registry: registry,
                                    ),
                                  ),
                                ),
                              );
                            },
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
                                    if (mounted)
                                      setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          if (mounted) setState(() => _searchQuery = val);
                        },
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
                        refresh,
                        prefillTags: prefillTags,
                        restrictToAttributes: widget.folder.visibleAttributes,
                      );
                      refresh();
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
                      child: const Icon(
                        CupertinoIcons.add,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
