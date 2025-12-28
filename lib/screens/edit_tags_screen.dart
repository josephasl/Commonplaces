import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../storage_service.dart';
import '../models.dart';

class EditTagsScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;

  const EditTagsScreen({super.key, required this.storage, this.onUpdate});

  @override
  State<EditTagsScreen> createState() => _EditTagsScreenState();
}

class _EditTagsScreenState extends State<EditTagsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _currentSort = SortOption.nameAsc;

  Map<String, int> _tagCounts = {};

  @override
  void initState() {
    super.initState();
    _calculateTagCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _calculateTagCounts() {
    final entries = widget.storage.getAllEntries();
    final Map<String, int> counts = {};

    for (var entry in entries) {
      final rawTag = entry.getAttribute('tag');
      List<String> tags = [];
      if (rawTag is String)
        tags = [rawTag];
      else if (rawTag is List)
        tags = List<String>.from(rawTag);

      for (var t in tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    setState(() {
      _tagCounts = counts;
    });
  }

  void _refresh() {
    _calculateTagCounts();
    widget.onUpdate?.call();
  }

  // --- ACTIONS (Rename/Add/Delete omitted for brevity, same as previous) ---
  // ... Paste existing dialog functions here if not using full file ...
  Future<void> _showAddTagDialog() async {
    final TextEditingController controller = TextEditingController();
    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("New Tag"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: "Tag Name",
            autofocus: true,
            textCapitalization: TextCapitalization.none,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            child: const Text("Create"),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await widget.storage.addGlobalTag(controller.text);
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
    _refresh();
  }

  Future<void> _renameTag(String oldTag) async {
    final TextEditingController renameController = TextEditingController(
      text: oldTag,
    );
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("Rename '$oldTag'"),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: CupertinoTextField(
            controller: renameController,
            autofocus: true,
            placeholder: "New Name",
            clearButtonMode: OverlayVisibilityMode.editing,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text("Save"),
            onPressed: () async {
              if (renameController.text.isNotEmpty) {
                await widget.storage.renameGlobalTag(
                  oldTag,
                  renameController.text,
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
    _refresh();
  }

  Future<void> _confirmDelete(String tag) async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Delete Tag?"),
        content: Text("Delete '$tag'?\nThis removes it from all entries."),
        actions: [
          CupertinoDialogAction(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.storage.removeGlobalTag(tag);
              _refresh();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text("Sort Tags By"),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = SortOption.nameAsc);
              Navigator.pop(ctx);
            },
            child: const Text("Name (A-Z)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = SortOption.nameDesc);
              Navigator.pop(ctx);
            },
            child: const Text("Name (Z-A)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = SortOption.countHighToLow);
              Navigator.pop(ctx);
            },
            child: const Text("Entry Count (High to Low)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = SortOption.countLowToHigh);
              Navigator.pop(ctx);
            },
            child: const Text("Entry Count (Low to High)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = SortOption.updatedNewest);
              Navigator.pop(ctx);
            },
            child: const Text("Date Modified (Newest)"),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _currentSort = SortOption.createdNewest);
              Navigator.pop(ctx);
            },
            child: const Text("Date Created (Newest)"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> displayTags = widget.storage.getGlobalTags();

    if (_searchQuery.isNotEmpty) {
      displayTags = displayTags.where((tag) {
        return tag.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    displayTags.sort((a, b) {
      switch (_currentSort) {
        case SortOption.nameAsc:
          return a.toLowerCase().compareTo(b.toLowerCase());
        case SortOption.nameDesc:
          return b.toLowerCase().compareTo(a.toLowerCase());
        case SortOption.countHighToLow:
          return (_tagCounts[b] ?? 0).compareTo(_tagCounts[a] ?? 0);
        case SortOption.countLowToHigh:
          return (_tagCounts[a] ?? 0).compareTo(_tagCounts[b] ?? 0);
        case SortOption.createdOldest:
          return 0; // Default index
        case SortOption.createdNewest:
          return -1; // Reversed in next step
        case SortOption.updatedNewest:
          return -1; // Assuming updated = re-added to end of list
      }
    });

    // Simple reverse for "newest" since storage returns oldest-first by default
    if (_currentSort == SortOption.createdNewest ||
        _currentSort == SortOption.updatedNewest) {
      displayTags = displayTags.reversed.toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Manage Tags",
          style: TextStyle(
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
      ),
      body: Stack(
        children: [
          // 1. LIST
          Column(
            children: [
              Expanded(
                child: displayTags.isEmpty
                    ? Center(
                        child: Text(
                          widget.storage.getGlobalTags().isEmpty
                              ? "No tags created"
                              : "No matches",
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: displayTags.length,
                        separatorBuilder: (c, i) => Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                          indent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final tag = displayTags[index];
                          final count = _tagCounts[tag] ?? 0;

                          return Dismissible(
                            key: Key(tag),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              color: CupertinoColors.activeBlue,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child: const Icon(
                                CupertinoIcons.pencil,
                                color: Colors.white,
                              ),
                            ),
                            secondaryBackground: Container(
                              color: CupertinoColors.destructiveRed,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                CupertinoIcons.trash,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                _renameTag(tag);
                                return false;
                              } else {
                                _confirmDelete(tag);
                                return false;
                              }
                            },
                            child: Container(
                              color: Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 4,
                                ),
                                title: Text(
                                  "#${tag.toLowerCase()}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                trailing: Text(
                                  "$count",
                                  style: const TextStyle(
                                    color: CupertinoColors.systemGrey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // 2. FLOATING UI
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
                        hintText: "Search tags...",
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
                  onTap: _showAddTagDialog,
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
