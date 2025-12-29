import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'models.dart';
import 'attributes.dart';

class EntryCard extends StatelessWidget {
  final AppEntry entry;
  final List<String>? visibleAttributes;
  final Color Function(String)? tagColorResolver;
  final Map<String, AttributeDefinition> registry;

  const EntryCard({
    super.key,
    required this.entry,
    required this.registry,
    this.visibleAttributes,
    this.tagColorResolver,
  });

  @override
  Widget build(BuildContext context) {
    final keysToShow = visibleAttributes ?? ['title', 'tag', 'notes'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: keysToShow.map((key) {
          final definition = registry[key];
          if (definition == null) return const SizedBox.shrink();

          final value = entry.getAttribute(key);
          final bool isEmpty = value == null || value.toString().isEmpty;
          final bool isImage = definition.type == AttributeValueType.image;

          if (isEmpty && !isImage) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: _buildAttributeRenderer(definition, value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttributeRenderer(AttributeDefinition def, dynamic value) {
    if (def.key == 'title') {
      return Text(
        value.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      );
    }

    if (def.key == 'tag') {
      List<String> tags = [];
      if (value is String)
        tags = [value];
      else if (value is List)
        tags = value.map((e) => e.toString()).toList();

      if (tags.isEmpty) return const SizedBox.shrink();

      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: tags.map((t) {
          Color bg = Colors.grey.shade100;
          Color txt = Colors.grey.shade800;
          if (tagColorResolver != null) {
            final catColor = tagColorResolver!(t);
            if (catColor != CupertinoColors.systemGrey) {
              bg = catColor.withOpacity(0.15);
              txt = catColor.withOpacity(1.0);
            }
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "#$t",
              style: TextStyle(
                fontSize: 10,
                color: txt,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      );
    }

    // Default Renderers
    switch (def.type) {
      case AttributeValueType.date:
        if (value == null) return const SizedBox.shrink();
        DateTime? d;
        if (value is DateTime)
          d = value;
        else if (value is String)
          d = DateTime.tryParse(value);
        final dateStr = d != null
            ? "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}"
            : value.toString();
        return Row(
          children: [
            Icon(
              def.key.contains('Created') || def.key.contains('Edited')
                  ? Icons.access_time
                  : Icons.calendar_today,
              size: 12,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
      case AttributeValueType.number:
        if (def.key == 'starRating')
          return Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              Text(" $value", style: const TextStyle(fontSize: 12)),
            ],
          );
        return Text(
          "${def.label}: $value",
          style: const TextStyle(fontSize: 12),
        );
      case AttributeValueType.image:
        final hasUrl = value != null && value.toString().isNotEmpty;
        return Container(
          width: double.infinity,
          height: 120,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasUrl
              ? Image.network(
                  value.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                )
              : const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.black12,
                    size: 40,
                  ),
                ),
        );
      default:
        return Text(
          value.toString(),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        );
    }
  }
}

class FolderCard extends StatelessWidget {
  final AppFolder folder;
  final Color? color;
  final int entryCount;
  final Color Function(String)? tagColorResolver;

  const FolderCard({
    super.key,
    required this.folder,
    this.color,
    this.entryCount = 0,
    this.tagColorResolver,
  });

  // --- Helper to mix tag colors ---
  Color _getMixedColor() {
    // 1. If an override color exists (like for "Untagged" folder), use it.
    if (color != null) return color!;

    // 2. If no tags or no resolver, return default blue
    if (folder.displayTags.isEmpty || tagColorResolver == null) {
      return CupertinoColors.activeBlue;
    }

    // 3. Collect all colors
    List<Color> colors = [];
    for (var tag in folder.displayTags) {
      colors.add(tagColorResolver!(tag));
    }

    if (colors.isEmpty) return CupertinoColors.activeBlue;

    // 4. Mix RGB values
    int r = 0, g = 0, b = 0;
    for (var c in colors) {
      r += c.red;
      g += c.green;
      b += c.blue;
    }

    // Return average color
    return Color.fromARGB(
      255,
      (r / colors.length).round(),
      (g / colors.length).round(),
      (b / colors.length).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the mixed color
    final baseColor = _getMixedColor();

    // Determine background (pastel) and foreground (strong)
    // If the base color is explicitly provided (like the Grey for Untagged), respect it.
    final bool isOverride = color != null;

    final bg = isOverride ? color! : baseColor.withOpacity(0.15);
    final fg = isOverride ? Colors.grey.shade600 : baseColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(CupertinoIcons.folder_solid, size: 32, color: fg),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$entryCount",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: fg.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            folder.getAttribute<String>('title') ?? "Untitled",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          if (folder.displayTags.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: folder.displayTags.take(3).map((t) {
                // Individual chips inside the folder card keep their own specific color
                Color chipColor = Colors.grey;
                if (tagColorResolver != null) {
                  chipColor = tagColorResolver!(t);
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: chipColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    "#$t",
                    style: TextStyle(
                      fontSize: 10,
                      color: chipColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}
