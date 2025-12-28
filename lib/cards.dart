import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'models.dart';
import 'attributes.dart';

class EntryCard extends StatelessWidget {
  final AppEntry entry;
  final List<String>? visibleAttributes;
  final Color Function(String)? tagColorResolver;

  const EntryCard({
    super.key,
    required this.entry,
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
          final definition = attributeRegistry[key];
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

    // ... [Rest of switch case logic same as before] ...
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
              def.key == 'dateCreated' || def.key == 'dateEdited'
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                CupertinoIcons.folder_solid,
                size: 32,
                color: color != null
                    ? Colors.grey.shade600
                    : CupertinoColors.activeBlue,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$entryCount",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
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
                Color bg = Colors.white;
                Color txt = Colors.grey.shade700;

                if (tagColorResolver != null) {
                  final catColor = tagColorResolver!(t);
                  if (catColor != CupertinoColors.systemGrey) {
                    bg = catColor.withOpacity(0.15);
                    txt = catColor.withOpacity(1.0);
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(4),
                    border: bg == Colors.white
                        ? Border.all(color: Colors.black.withOpacity(0.05))
                        : null,
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
            )
          else
            // FIXED: Use SizedBox instead of Text(" ")
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}
