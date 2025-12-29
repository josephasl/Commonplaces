import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models.dart';
import '../attributes.dart';
import '../storage_service.dart';
import '../dialogs.dart';

class EntryScreen extends StatefulWidget {
  final AppEntry entry;
  final AppFolder folder;
  final StorageService storage;
  final VoidCallback onBack;

  const EntryScreen({
    super.key,
    required this.entry,
    required this.folder,
    required this.storage,
    required this.onBack,
  });

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final visibleKeys = widget.folder.visibleAttributes;
    final customAttrs = widget.storage.getCustomAttributes(); // Fetch customs
    final registry = getAttributeRegistry(customAttrs); // Merge

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < 0) {
          setState(() {
            _dragOffset += details.primaryDelta!;
          });
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffset < -100 || (details.primaryVelocity ?? 0) < -200) {
          widget.onBack();
        } else {
          setState(() {
            _dragOffset = 0;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.back, color: Colors.black),
              onPressed: widget.onBack,
            ),
            title: Text(
              widget.entry.getAttribute<String>('title') ?? "Entry",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  CupertinoIcons.ellipsis,
                  color: Colors.black,
                  size: 20,
                ),
                onPressed: () => showEditEntryDialog(
                  context,
                  widget.entry,
                  widget.folder,
                  widget.storage,
                  () {
                    final all = widget.storage.getAllEntries();
                    final exists = all.any((e) => e.id == widget.entry.id);

                    if (!exists) {
                      widget.onBack();
                    } else {
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(color: Colors.grey.shade200, height: 1.0),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...visibleKeys.map((key) {
                  final definition = registry[key]; // Use the merged registry
                  if (definition == null) return const SizedBox.shrink();
                  // ...
                  final value = widget.entry.getAttribute(key);

                  // --- CHANGED LOGIC HERE ---
                  final bool isEmpty =
                      value == null || value.toString().isEmpty;

                  // If it's empty AND NOT an image, hide it.
                  // If it IS an image, we let it pass through so the placeholder shows.
                  if (isEmpty && definition.type != AttributeValueType.image) {
                    return const SizedBox.shrink();
                  }
                  // --------------------------

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: _buildAttributeDisplay(definition, value),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeDisplay(AttributeDefinition def, dynamic value) {
    if (def.type == AttributeValueType.image) {
      final bool hasUrl = value != null && value.toString().isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(def.label),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: hasUrl
                ? Image.network(
                    value.toString(),
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(), // This will now trigger if value is null/empty
          ),
        ],
      );
    }
    if (def.key == 'tag') {
      List<String> tags = (value is List)
          ? value.map((e) => e.toString()).toList()
          : [value.toString()];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(def.label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((t) {
              final color = widget.storage.getTagColor(t);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "#$t",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (def.key != 'title') _buildLabel(def.label),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: def.key == 'title' ? 24 : 16,
            fontWeight: def.key == 'title'
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.photo, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            "No Image Provided",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }
}
