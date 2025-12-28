import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'models.dart';
import 'attributes.dart';

class EntryCard extends StatelessWidget {
  final AppEntry entry;
  final List<String>? visibleAttributes;

  const EntryCard({super.key, required this.entry, this.visibleAttributes});

  @override
  Widget build(BuildContext context) {
    // Default to these 3 if nothing is specified
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
          final value = entry.getAttribute(key);

          // --- CRASH FIX: Safety Check ---
          // If the registry doesn't have this key, skip rendering instead of crashing.
          if (definition == null) {
            return const SizedBox.shrink();
          }

          final bool isEmpty = value == null || value.toString().isEmpty;
          final bool isImage = definition.type == AttributeValueType.image;

          // Hide empty text/number fields (but show empty image placeholders if you want)
          if (isEmpty && !isImage) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: _buildAttributeRenderer(definition, value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttributeRenderer(AttributeDefinition def, dynamic value) {
    // 1. Title
    if (def.key == 'title') {
      return Text(
        value.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      );
    }

    // 2. Tags
    if (def.key == 'tag') {
      List<String> tags = [];
      if (value is String)
        tags = [value];
      else if (value is List)
        tags = List<String>.from(value);

      if (tags.isEmpty) return const SizedBox.shrink();

      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: tags
            .map(
              (t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "#$t",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    // 3. Other Types
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
        if (def.key == 'starRating') {
          return Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              Text(" $value", style: const TextStyle(fontSize: 12)),
            ],
          );
        }
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
                  errorBuilder: (context, error, stackTrace) => const Center(
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
        // Text and List fallbacks
        return Text(
          value.toString(),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        );
    }
  }
}

// FOLDER CARD (No changes needed, but included for completeness)
class FolderCard extends StatelessWidget {
  final AppFolder folder;
  final Color? color;
  final int entryCount;

  const FolderCard({
    super.key,
    required this.folder,
    this.color,
    this.entryCount = 0,
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
              children: folder.displayTags
                  .take(3)
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          else
            const Text(
              "No tags filtered",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
