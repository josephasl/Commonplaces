import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../ui/app_styles.dart';

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
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 60),
      decoration: AppDecorations.card,
      padding: const EdgeInsets.all(AppDimens.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: keysToShow.map((key) {
          final definition = registry[key];
          if (definition == null) return const SizedBox.shrink();
          final value = entry.getAttribute(key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: _buildAttributeRenderer(definition, value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttributeRenderer(AttributeDefinition def, dynamic value) {
    final bool isEmpty =
        value == null ||
        value.toString().isEmpty ||
        (value is List && value.isEmpty);

    if (def.key == 'title') {
      return Text(
        isEmpty ? "-" : value.toString(),
        style: AppTextStyles.cardTitle,
      );
    }

    if (def.key == 'tag') {
      if (isEmpty) return Text("-", style: AppTextStyles.caption);
      List<String> tags = [];
      if (value is String)
        tags = [value];
      else if (value is List)
        tags = value.map((e) => e.toString()).toList();

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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppDimens.cornerRadiusLess),
            ),
            child: Text(
              "#$t",
              style: AppTextStyles.labelSmall.copyWith(color: txt),
            ),
          );
        }).toList(),
      );
    }

    if (def.type == AttributeValueType.image) {
      final hasUrl = !isEmpty;
      final isLocal = hasUrl && !value.toString().startsWith('http');
      return Container(
        width: double.infinity,
        height: 120,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(AppDimens.cornerRadiusLess),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasUrl
            ? (isLocal
                  ? Image.file(
                      File(value.toString()),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  : Image.network(
                      value.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ))
            : const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.black12,
                  size: 40,
                ),
              ),
      );
    }

    if (def.type == AttributeValueType.date) {
      String dateStr = "-";
      if (!isEmpty) {
        DateTime? d;
        if (value is DateTime)
          d = value;
        else if (value is String)
          d = DateTime.tryParse(value);
        if (d != null)
          dateStr =
              "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
        else
          dateStr = value.toString();
      }
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
          Text(dateStr, style: AppTextStyles.cardBody),
        ],
      );
    }

    if (def.type == AttributeValueType.rating) {
      final int rating = (value is int)
          ? value
          : (int.tryParse(value?.toString() ?? '0') ?? 0);

      if (isEmpty) return Text("-", style: AppTextStyles.caption);

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          return Icon(
            index < rating ? CupertinoIcons.star_fill : CupertinoIcons.star,
            size: 14,
            color: CupertinoColors.systemYellow,
          );
        }),
      );
    }

    if (def.type == AttributeValueType.number) {
      return Text(
        "${def.label}: ${isEmpty ? '-' : value}",
        style: AppTextStyles.caption,
      );
    }

    return Text(
      isEmpty ? "-" : value.toString(),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.cardBody,
    );
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

  Color _getMixedColor() {
    if (color != null) return color!;
    if (folder.displayTags.isEmpty || tagColorResolver == null)
      return CupertinoColors.activeBlue;
    List<Color> colors = [];
    for (var tag in folder.displayTags) colors.add(tagColorResolver!(tag));
    if (colors.isEmpty) return CupertinoColors.activeBlue;
    int r = 0, g = 0, b = 0;
    for (var c in colors) {
      r += c.red;
      g += c.green;
      b += c.blue;
    }
    return Color.fromARGB(
      255,
      (r / colors.length).round(),
      (g / colors.length).round(),
      (b / colors.length).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _getMixedColor();
    final bool isOverride = color != null;
    final bg = isOverride ? color! : baseColor.withOpacity(0.15);
    final fg = isOverride ? Colors.grey.shade600 : baseColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
      ),
      padding: const EdgeInsets.all(AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                AppConstants.categoryIcons[folder.iconIndex],
                size: 32,
                color: fg,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
                ),
                child: Text(
                  "$entryCount",
                  style: AppTextStyles.countLabel.copyWith(
                    color: fg.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spacingM),
          Text(
            folder.getAttribute<String>('title') ?? "Untitled",
            style: AppTextStyles.cardTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimens.spacingS),
          if (folder.displayTags.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: folder.displayTags.take(3).map((t) {
                Color chipColor = Colors.grey;
                if (tagColorResolver != null) chipColor = tagColorResolver!(t);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppDimens.cornerRadiusLess,
                    ),
                    border: Border.all(
                      color: chipColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    "#$t",
                    style: AppTextStyles.labelSmall.copyWith(color: chipColor),
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
