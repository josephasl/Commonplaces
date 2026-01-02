import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models.dart';
import '../../storage_service.dart';
import '../cards.dart';
import '../dialogs.dart';
import '../../attributes.dart';
import '../ui/app_styles.dart';
import 'entry_screen.dart';
import '../ui/dialogs/sort_bottom_sheet.dart';
import '../shakeable.dart';

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
  late String _sortAttributeKey;
  late bool _isAscending;
  String? _lastViewedEntryId;
  Offset _dragStart = Offset.zero;
  bool _isEditing = false;

  void updateLastViewedEntry(String id) {
    _lastViewedEntryId = id;
  }

  void stopEditing() {
    if (_isEditing) setState(() => _isEditing = false);
  }

  @override
  void initState() {
    super.initState();
    if (widget.folder.id != 'untagged_special_id') {
      _activeTags = Set.from(widget.folder.displayTags);
    }

    // --- LOAD SAVED SORT PREFS ---
    _sortAttributeKey = widget.folder.sortKey;
    _isAscending = widget.folder.sortAscending;

    if (!widget.folder.activeAttributes.contains(_sortAttributeKey) &&
        _sortAttributeKey != 'dateCreated' &&
        widget.folder.activeAttributes.isNotEmpty) {
      _sortAttributeKey = widget.folder.activeAttributes.first;
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
        setState(() => _activeTags = Set.from(widget.folder.displayTags));
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

  Future<void> _showSortSheet() async {
    final customAttrs = widget.storage.getCustomAttributes();
    final registry = getAttributeRegistry(customAttrs);

    final List<SortOptionItem> options = widget.folder.activeAttributes
        .map((key) {
          final def = registry[key];
          if (def == null) return null;
          return SortOptionItem(key, def.label);
        })
        .whereType<SortOptionItem>()
        .toList();

    if (options.isEmpty) return;

    final result = await showUnifiedSortSheet(
      context: context,
      title: "Sort Entries By",
      options: options,
      currentSortKey: _sortAttributeKey,
      currentIsAscending: _isAscending,
    );

    if (result != null && mounted) {
      setState(() {
        _sortAttributeKey = result.key;
        _isAscending = result.isAscending;
      });

      if (widget.folder.id != 'untagged_special_id') {
        widget.folder.setSortPreferences(_sortAttributeKey, _isAscending);
        await widget.storage.saveFolder(widget.folder);
      }
    }
  }

  void _openLastViewedEntry(List<AppEntry> currentList) {
    if (_lastViewedEntryId == null) return;
    final index = currentList.indexWhere((e) => e.id == _lastViewedEntryId);
    if (index != -1) widget.onEntryTap(currentList, index);
  }

  void _deleteEntry(AppEntry entry) {
    showDeleteConfirmationDialog(
      context: context,
      title: "Delete Entry?",
      message: "Delete this entry?",
      onConfirm: () async {
        await widget.storage.deleteEntry(entry.id);
        refresh();
      },
    );
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
        final searchStr = entry.attributes.values.join(' ').toLowerCase();
        return searchStr.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    processedEntries.sort((a, b) {
      final def = registry[_sortAttributeKey];
      dynamic valA = a.getAttribute(_sortAttributeKey);
      dynamic valB = b.getAttribute(_sortAttributeKey);
      int result = 0;
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
      onPointerDown: (event) => _dragStart = event.position,
      onPointerUp: (event) {
        final delta = event.position - _dragStart;
        if (delta.dx < -50 && delta.dy.abs() < 50)
          _openLastViewedEntry(processedEntries);
      },
      child: Scaffold(
        backgroundColor: Colors.white,

        appBar: AppBar(
          title: Text(
            widget.folder.getAttribute<String>('title') ?? "Folder",
            style: AppTextStyles.header,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: Colors.grey.shade200, height: 1.0),
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
            else if (widget.folder.id != 'untagged_special_id')
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
                  if (addedTags.isNotEmpty && mounted)
                    setState(() => _activeTags.addAll(addedTags));
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
                    height: 62,
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
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
                            setState(
                              () => isActive
                                  ? _activeTags.remove(tag)
                                  : _activeTags.add(tag),
                            );
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
                              borderRadius: BorderRadius.circular(24),
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
                  child: GestureDetector(
                    onTap: () {
                      if (_isEditing) setState(() => _isEditing = false);
                    },
                    child: Padding(
                      // Only padding left/right here.
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: MasonryGridView.count(
                        controller: _scrollController,
                        key: PageStorageKey('folder_grid_${widget.folder.id}'),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        // Bottom padding here allows scrolling BEHIND floating elements
                        padding: const EdgeInsets.only(bottom: 100),
                        crossAxisCount: 2,
                        mainAxisSpacing: 0,
                        crossAxisSpacing: 0,
                        itemCount: processedEntries.length,
                        itemBuilder: (context, index) {
                          final entry = processedEntries[index];

                          return GestureDetector(
                            onLongPress: () =>
                                setState(() => _isEditing = true),
                            onTap: () {
                              if (_isEditing) {
                                setState(() => _isEditing = false);
                              } else {
                                updateLastViewedEntry(entry.id);
                                widget.onEntryTap(processedEntries, index);
                              }
                            },
                            child: Shakeable(
                              enabled: _isEditing,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(5.0),
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
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => _deleteEntry(entry),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8E8E93),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
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
                        folderContext: widget.folder,
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
