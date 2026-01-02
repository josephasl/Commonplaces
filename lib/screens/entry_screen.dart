import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models.dart';
import '../../attributes.dart';
import '../../storage_service.dart';
import '../ui/app_styles.dart';
import '../dialogs.dart';

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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) => _isSwitchingPage = false);
  }

  void _goToPreviousPage() {
    if (_isSwitchingPage || _currentIndex <= 0) return;
    _isSwitchingPage = true;
    _pageController
        .previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) => _isSwitchingPage = false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleKeys = widget.folder.visibleAttributes;
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,

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
                  color: Colors.black,
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
            child: Container(color: Colors.grey.shade200, height: 1.0),
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
                      color: Colors.white,
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notification) {
                          const double threshold = 60.0;
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
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: visibleKeys.map((key) {
                                final definition = registry[key];
                                if (definition == null)
                                  return const SizedBox.shrink();
                                final value = entry.getAttribute(key);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  child: _buildAttributeDisplay(
                                    definition,
                                    value,
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
    StorageService storage,
  ) {
    final bool isEmpty =
        value == null ||
        value.toString().isEmpty ||
        (value is List && value.isEmpty);

    if (def.type == AttributeValueType.image) {
      final bool hasUrl = !isEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: hasUrl
                ? Image.network(
                    value.toString(),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
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
              spacing: 8,
              runSpacing: 8,
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
                            borderRadius: BorderRadius.circular(6),
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
          dateStr =
              "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
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
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
