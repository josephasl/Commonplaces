import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../models.dart';
import '../../storage_service.dart';
import '../cards.dart';
import '../dialogs.dart';
import '../../attributes.dart';
import '../ui/app_styles.dart';
import '../shakeable.dart';
import '../ui/widgets/common_ui.dart';

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
  final ScrollController _horizontalScrollController = ScrollController();
  String _searchQuery = '';
  late String _sortAttributeKey;
  late bool _isAscending;
  String? _lastViewedEntryId;
  Offset _dragStart = Offset.zero;
  bool _isEditing = false;
  bool _isNavigatingBack = false;
  bool _isSelectionMode = false;
  Set<String> _selectedEntryIds = {};
  Map<String, int> _randomSortValues = {};
  int _sortSeed = 0;

  void updateLastViewedEntry(String id) {
    _lastViewedEntryId = id;
  }

  void stopEditing() {
    if (_isEditing) setState(() => _isEditing = false);
    if (_isSelectionMode)
      setState(() {
        _isSelectionMode = false;
        _selectedEntryIds.clear();
      });
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
        _sortAttributeKey != 'random' &&
        widget.folder.activeAttributes.isNotEmpty) {
      _sortAttributeKey = widget.folder.activeAttributes.first;
    }

    // Initial data load
    if (widget.folder.id == 'untagged_special_id') {
      _allFolderEntries = widget.storage.getUntaggedEntries();
    } else {
      _allFolderEntries = widget.storage.getEntriesForFolder(widget.folder);
    }

    if (widget.folder.id != 'untagged_special_id') {
      final currentTags = widget.folder.displayTags;
      _activeTags = _activeTags.intersection(currentTags.toSet());
      if (_activeTags.isEmpty && currentTags.isNotEmpty) {
        _activeTags = currentTags.toSet();
      }
    }

    // FIX 1: Generate values immediately in initState if needed
    if (_sortAttributeKey == 'random') {
      _regenerateRandomValues();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tagScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void handleNavTap() {
    if (!mounted) return;
    bool didScroll = false;
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      didScroll = true;
    }
    if (_horizontalScrollController.hasClients &&
        _horizontalScrollController.offset > 0) {
      _horizontalScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      didScroll = true;
    }
    if (!didScroll && widget.folder.id != 'untagged_special_id') {
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
        // FIX 2: Regenerate on refresh if mode is random
        if (_sortAttributeKey == 'random') {
          _reconcileRandomValues();
        }
      });
    } else {
      _allFolderEntries = entries;
    }
  }

  void _reconcileRandomValues() {
    final currentIds = _allFolderEntries.map((e) => e.id).toSet();
    _randomSortValues.removeWhere((id, _) => !currentIds.contains(id));

    int maxVal = _randomSortValues.isEmpty
        ? 0
        : _randomSortValues.values.reduce(math.max);

    for (var entry in _allFolderEntries) {
      if (!_randomSortValues.containsKey(entry.id)) {
        maxVal++;
        _randomSortValues[entry.id] = maxVal;
      }
    }
  }

  void _regenerateRandomValues() {
    var entries = List<AppEntry>.from(_allFolderEntries);
    entries.shuffle();
    _randomSortValues = {
      for (var i = 0; i < entries.length; i++) entries[i].id: i,
    };
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
    options.add(const SortOptionItem('random', 'Random'));
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
        if (result.key == 'random') {
          _sortAttributeKey = 'random';
          _isAscending = true;
          _regenerateRandomValues(); // This updates the map
          _sortSeed++;
        } else {
          _sortAttributeKey = result.key;
          _isAscending = result.isAscending;
        }
      });
      // The setState above forces build -> sort -> updated view.
      // We do NOT need to change the PageStorageKey.

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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedEntryIds.contains(id)) {
        _selectedEntryIds.remove(id);
      } else {
        _selectedEntryIds.add(id);
        _isSelectionMode = true;
      }
    });
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

    // FIX 3: Removed the "lazy" regeneration check here.
    // We rely on initState, refresh, and _showSortSheet to handle it.

    processedEntries.sort((a, b) {
      if (_sortAttributeKey == 'random') {
        final rA = _randomSortValues[a.id] ?? 0;
        final rB = _randomSortValues[b.id] ?? 0;
        return rA.compareTo(rB);
      }

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
    final isListLayout = widget.folder.layout == 'list';
    double listWidth = (AppDimens.paddingM * 2) + (AppDimens.paddingL * 2);
    for (var key in visibleAttrs) {
      final def = registry[key];
      if (def != null) listWidth += EntryRow.getColumnWidth(def);
    }

    final pageKey = PageStorageKey(
      'folder_${isListLayout ? 'list' : 'grid'}_${widget.folder.id}_$_sortSeed',
    );

    return Listener(
      onPointerDown: (event) => _dragStart = event.position,
      onPointerUp: (event) {
        if (isListLayout) return;
        final delta = event.position - _dragStart;
        if (delta.dx < -50 && delta.dy.abs() < 50)
          _openLastViewedEntry(processedEntries);
      },
      child: Scaffold(
        backgroundColor: AppColors.coloredBackground,
        appBar: AppBar(
          leadingWidth: _isSelectionMode ? 100 : null,
          leading: _isSelectionMode
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Cancel",
                      style: AppTextStyles.button.copyWith(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    onPressed: () => setState(() {
                      _isSelectionMode = false;
                      _selectedEntryIds.clear();
                    }),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    CupertinoIcons.checkmark_circle,
                    color: AppColors.primary,
                  ),
                  onPressed: () => setState(() => _isSelectionMode = true),
                ),
          title: Text(
            _isSelectionMode
                ? "Select Items"
                : (widget.folder.getAttribute<String>('title') ?? "Folder"),
            style: AppTextStyles.header,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: AppColors.divider, height: 1.0),
          ),
          actions: [
            if (_isSelectionMode)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _selectedEntryIds.isEmpty
                    ? null
                    : () {
                        final selectedEntries = processedEntries
                            .where((e) => _selectedEntryIds.contains(e.id))
                            .toList();
                        showEditMultipleEntriesDialog(
                          context,
                          selectedEntries,
                          widget.storage,
                          () {
                            setState(() {
                              _isSelectionMode = false;
                              _selectedEntryIds.clear();
                            });
                            refresh();
                          },
                        );
                      },
                child: Text(
                  "Edit (${_selectedEntryIds.length})",
                  style: AppTextStyles.button.copyWith(
                    fontWeight: FontWeight.normal,
                  ),
                ),
              )
            else if (_isEditing)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "Done",
                  style: AppTextStyles.button.copyWith(
                    fontWeight: FontWeight.normal,
                  ),
                ),
                onPressed: () => setState(() => _isEditing = false),
              )
            else if (widget.folder.id != 'untagged_special_id')
              IconButton(
                icon: const Icon(
                  CupertinoIcons.ellipsis,
                  color: AppColors.primary,
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
                  final currentTagSet = Set<String>.from(currentTags);
                  if (previousTags.length != currentTagSet.length ||
                      !previousTags.containsAll(currentTagSet)) {
                    _lastViewedEntryId = null;
                  }
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
            GestureDetector(
              onTap: () {
                if (_isEditing && !_isSelectionMode)
                  setState(() => _isEditing = false);
              },
              child: isListLayout
                  ? NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis == Axis.horizontal &&
                            notification.dragDetails != null &&
                            !_isNavigatingBack) {
                          if (notification.metrics.pixels < -20) {
                            _isNavigatingBack = true;
                            if (widget.onBack != null) {
                              widget.onBack!();
                            } else {
                              Navigator.of(context).maybePop();
                            }
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                if (mounted) _isNavigatingBack = false;
                              },
                            );
                          } else if (notification.metrics.pixels >
                              notification.metrics.maxScrollExtent + 20) {
                            _isNavigatingBack = true;
                            _openLastViewedEntry(processedEntries);
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                if (mounted) _isNavigatingBack = false;
                              },
                            );
                          }
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: math.max(
                            MediaQuery.of(context).size.width,
                            listWidth,
                          ),
                          child: ListView.builder(
                            controller: _scrollController,
                            key: pageKey, // Stable Key
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              0,
                              widget.folder.displayTags.isNotEmpty ? 68 : 0,
                              0,
                              100,
                            ),
                            itemCount: processedEntries.length,
                            itemBuilder: (context, index) {
                              final entry = processedEntries[index];
                              final isSelected = _selectedEntryIds.contains(
                                entry.id,
                              );
                              return GestureDetector(
                                key: ValueKey(entry.id),
                                behavior: HitTestBehavior.opaque,
                                onLongPress: () =>
                                    setState(() => _isEditing = true),
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelection(entry.id);
                                  } else if (_isEditing) {
                                    setState(() => _isEditing = false);
                                  } else {
                                    updateLastViewedEntry(entry.id);
                                    widget.onEntryTap(processedEntries, index);
                                  }
                                },
                                child: ShakeableWithDelete(
                                  enabled: _isEditing && !_isSelectionMode,
                                  onDelete: () => _deleteEntry(entry),
                                  child: EntryRow(
                                    entry: entry,
                                    isSelected: isSelected,
                                    visibleAttributes: visibleAttrs,
                                    tagColorResolver:
                                        widget.storage.getTagColor,
                                    registry: registry,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  : MasonryGridView.count(
                      controller: _scrollController,
                      key: pageKey, // Stable Key
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        8,
                        widget.folder.displayTags.isNotEmpty ? 68 : 10,
                        8,
                        100,
                      ),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      itemCount: processedEntries.length,
                      itemBuilder: (context, index) {
                        final entry = processedEntries[index];
                        final isSelected = _selectedEntryIds.contains(entry.id);
                        return GestureDetector(
                          key: ValueKey(entry.id),
                          onLongPress: () => setState(() => _isEditing = true),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(entry.id);
                            } else if (_isEditing) {
                              setState(() => _isEditing = false);
                            } else {
                              updateLastViewedEntry(entry.id);
                              widget.onEntryTap(processedEntries, index);
                            }
                          },
                          child: ShakeableWithDelete(
                            enabled: _isEditing && !_isSelectionMode,
                            onDelete: () => _deleteEntry(entry),
                            child: Hero(
                              tag: 'entry_hero_${entry.id}',
                              child: Material(
                                color: Colors.transparent,
                                child: EntryCard(
                                  entry: entry,
                                  isSelected: isSelected,
                                  visibleAttributes: visibleAttrs,
                                  tagColorResolver: widget.storage.getTagColor,
                                  registry: registry,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (widget.folder.displayTags.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 62,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: ShaderMask(
                    shaderCallback: AppShaders.maskFadeRight,
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      controller: _tagScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.folder.displayTags.length,
                      separatorBuilder: (c, i) =>
                          const SizedBox(width: AppDimens.spacingS),
                      itemBuilder: (context, index) {
                        final tag = widget.folder.displayTags[index];
                        final isActive = _activeTags.contains(tag);
                        final catColor = widget.storage.getTagColor(tag);
                        return AppTagChip(
                          label: tag,
                          color: catColor,
                          isActive: isActive,
                          onTap: () => setState(
                            () => isActive
                                ? _activeTags.remove(tag)
                                : _activeTags.add(tag),
                          ),
                        );
                      },
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
                      showClear: _searchQuery.isNotEmpty,
                      onClear: () {
                        _searchController.clear();
                        if (mounted) setState(() => _searchQuery = '');
                      },
                      onChanged: (val) {
                        if (mounted) setState(() => _searchQuery = val);
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingM),
                  AppFloatingButton(
                    icon: CupertinoIcons.sort_down,
                    onTap: _showSortSheet,
                  ),
                  if (!_isSelectionMode) ...[
                    const SizedBox(width: AppDimens.spacingM),
                    AppFloatingButton(
                      icon: CupertinoIcons.add,
                      color: AppColors.primary,
                      iconColor: Colors.white,
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
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
