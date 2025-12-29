import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../storage_service.dart';
import '../attributes.dart';
import '../models.dart';
import '../dialogs.dart';
import 'edit_tags_screen.dart';
import '../dialogs.dart'; // Ensure this is imported

class ManageLibraryScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;

  const ManageLibraryScreen({super.key, required this.storage, this.onUpdate});

  @override
  State<ManageLibraryScreen> createState() => _ManageLibraryScreenState();
}

class _ManageLibraryScreenState extends State<ManageLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes to update the AppBar actions (show/hide button)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
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
          ),
        ),
        // --- RESTORED ACTIONS ---
        actions: [
          // Only show "Add Category" if we are on the first tab (Tags)
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
                  ),
                  tabs: const [
                    Tab(text: "Group Tags"),
                    Tab(text: "Custom Attributes"),
                  ],
                  dividerColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,

        children: [
          // TAB 1: TAGS
          EditTagsScreen(storage: widget.storage, onUpdate: widget.onUpdate),

          // TAB 2: ATTRIBUTES
          _AttributesManager(
            storage: widget.storage,
            onUpdate: widget.onUpdate,
          ),
        ],
      ),
    );
  }
}

class _AttributesManager extends StatefulWidget {
  final StorageService storage;
  final VoidCallback? onUpdate;
  const _AttributesManager({required this.storage, this.onUpdate});

  @override
  State<_AttributesManager> createState() => _AttributesManagerState();
}

class _AttributesManagerState extends State<_AttributesManager> {
  void _refresh() {
    setState(() {});
    widget.onUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final customAttrs = widget.storage.getCustomAttributes();

    return Stack(
      children: [
        customAttrs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.slider_horizontal_3,
                      size: 60,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No custom attributes",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Add fields like 'Author' or 'Pages'",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: customAttrs.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final attr = customAttrs[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      title: Text(
                        attr.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Type: ${attr.type.name.toUpperCase()}"),
                      trailing: IconButton(
                        icon: const Icon(
                          CupertinoIcons.ellipsis, // Changed to Ellipsis
                          size: 18,
                          color: Colors.grey, // Changed color to grey
                        ),
                        // --- UPDATED ACTION ---
                        onPressed: () {
                          showAttributeOptionsDialog(
                            context,
                            widget.storage,
                            attr,
                            _refresh,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

        Positioned(
          bottom: 20,
          right: 16,
          child: GestureDetector(
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
        ),
      ],
    );
  }
}
