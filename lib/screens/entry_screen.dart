import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../../storage_service.dart';
import '../ui/app_styles.dart';
import '../dialogs.dart';
import 'full_screen_image.dart';
import '../ui/widgets/common_ui.dart';

class EntryScreen extends StatefulWidget {
  final List<AppEntry> entries;
  final int initialIndex;
  final AppFolder folder;
  final StorageService storage;
  final Function(AppEntry) onEntryChanged;

  const EntryScreen({
    super.key,
    required this.entries,
    required this.initialIndex,
    required this.folder,
    required this.storage,
    required this.onEntryChanged,
  });

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isSwitchingPage = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_isSwitchingPage || _currentIndex >= widget.entries.length - 1) return;
    _isSwitchingPage = true;
    _pageController
        .nextPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .then((_) => _isSwitchingPage = false);
  }

  void _goToPreviousPage() {
    if (_isSwitchingPage || _currentIndex <= 0) return;
    _isSwitchingPage = true;
    _pageController
        .previousPage(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .then((_) => _isSwitchingPage = false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleKeys = widget.folder.activeAttributes;
    final customAttrs = widget.storage.getCustomAttributes();
    final registry = getAttributeRegistry(customAttrs);
    final currentEntry =
        (widget.entries.isNotEmpty && _currentIndex < widget.entries.length)
        ? widget.entries[_currentIndex]
        : null;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 200)
          Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,

          elevation: 0,
          leading: const BackButton(color: Colors.black),
          title: Text(
            "${_currentIndex + 1} / ${widget.entries.length}",
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          centerTitle: true,
          actions: [
            if (currentEntry != null)
              IconButton(
                icon: const Icon(
                  CupertinoIcons.ellipsis,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () => showEditEntryDialog(
                  context,
                  currentEntry,
                  widget.folder,
                  widget.storage,
                  () {
                    final all = widget.storage.getAllEntries();
                    final exists = all.any((e) => e.id == currentEntry.id);
                    if (!exists) {
                      setState(() {
                        widget.entries.removeAt(_currentIndex);
                        if (_currentIndex >= widget.entries.length)
                          _currentIndex = (widget.entries.length - 1).clamp(
                            0,
                            99999,
                          );
                      });
                      if (widget.entries.isEmpty) Navigator.of(context).pop();
                    } else {
                      setState(() {});
                    }
                  },
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: AppColors.divider, height: 1.0),
          ),
        ),
        body: widget.entries.isEmpty
            ? const Center(child: Text("No entries"))
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  if (index < widget.entries.length)
                    widget.onEntryChanged(widget.entries[index]);
                },
                itemCount: widget.entries.length,
                itemBuilder: (context, index) {
                  final entry = widget.entries[index];
                  return Hero(
                    tag: 'entry_hero_${entry.id}',
                    child: Material(
                      color: AppColors.background,
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notification) {
                          const double threshold = 40.0;
                          final metrics = notification.metrics;
                          if (notification.dragDetails == null) return false;
                          if (metrics.pixels < -threshold)
                            _goToPreviousPage();
                          else if (metrics.pixels >
                              metrics.maxScrollExtent + threshold)
                            _goToNextPage();
                          return false;
                        },
                        child: SizedBox.expand(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(
                              AppDimens.paddingS,
                              AppDimens.paddingS,
                              AppDimens.paddingS,
                              100,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: visibleKeys.map((key) {
                                final definition = registry[key];
                                if (definition == null)
                                  return const SizedBox.shrink();
                                final value = entry.getAttribute(key);
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimens.paddingM,
                                  ),
                                  child: _buildAttributeDisplay(
                                    definition,
                                    value,
                                    entry,
                                    widget.storage,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildAttributeDisplay(
    AttributeDefinition def,
    dynamic value,
    AppEntry entry,
    StorageService storage,
  ) {
    final bool isEmpty =
        value == null ||
        value.toString().isEmpty ||
        (value is List && value.isEmpty);

    if (def.type == AttributeValueType.image) {
      final bool hasUrl = !isEmpty;
      final bool isLocal = hasUrl && !value.toString().startsWith('http');
      final String? sourceUrl = entry.getAttribute('${def.key}_source');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            //  borderRadius: BorderRadius.circular(AppDimens.cornerRadiusLess),
            child: hasUrl
                ? GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        AppPageRoute(
                          builder: (context) =>
                              FullScreenImageScreen(imageUrl: value.toString()),
                        ),
                      );
                    },
                    child: isLocal
                        ? Image.file(
                            File(value.toString()),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildPlaceholder(),
                          )
                        : Image.network(
                            value.toString(),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildPlaceholder(),
                          ),
                  )
                : _buildPlaceholder(),
          ),
          if (hasUrl && sourceUrl != null && sourceUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(sourceUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.globe,
                      size: 14,
                      color: AppColors.active,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Source: $sourceUrl",
                        style: const TextStyle(
                          color: AppColors.active,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    if (def.type == AttributeValueType.rating) {
      final rating = (!isEmpty && value is int)
          ? value
          : (int.tryParse(value.toString()) ?? 0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(def.label),
          isEmpty
              ? const Text("-", style: TextStyle(fontSize: 16))
              : Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < rating
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      color: CupertinoColors.systemYellow,
                      size: 24,
                    ),
                  ),
                ),
        ],
      );
    }

    if (def.key == 'tag') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(def.label),
          if (isEmpty)
            const Text("-", style: TextStyle(fontSize: 16))
          else
            Wrap(
              spacing: AppDimens.spacingS,
              runSpacing: AppDimens.spacingS,
              children:
                  ((value is List)
                          ? value.map((e) => e.toString()).toList()
                          : [value.toString()])
                      .map((t) {
                        final color = storage.getTagColor(t);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                              AppDimens.cornerRadius,
                            ),
                          ),
                          child: Text(
                            "#$t",
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      })
                      .toList(),
            ),
        ],
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
          dateStr = MaterialLocalizations.of(context).formatCompactDate(d);
        else
          dateStr = value.toString();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(def.label),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (def.key != 'title') _buildLabel(def.label),
        Text(
          isEmpty ? "-" : value.toString(),
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
        color: AppColors.inputBackground,
        //borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
        border: Border.all(color: AppColors.border.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.photo,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppDimens.spacingS),
          Text(
            "No Image Provided",
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
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
      padding: const EdgeInsets.only(bottom: AppDimens.spacingS),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
