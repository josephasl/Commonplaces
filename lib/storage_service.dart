import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'package:flutter/cupertino.dart';
import 'attributes.dart';

class StorageService {
  final Uuid _uuid = const Uuid();

  static const String _entriesBoxName = 'entries_box';
  static const String _foldersBoxName = 'folders_box';
  static const String _settingsBoxName = 'settings_box';

  static const String _globalTagsKey = 'global_tags';
  static const String _tagCategoriesKey = 'tag_categories';
  static const String _tagMappingKey = 'tag_mapping';
  static const String _expandedEntryAttributesKey = 'expanded_entry_attributes';

  static const String _defaultCategoryId = 'default_grey_cat';
  static const String _customAttributesKey = 'custom_attributes';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_entriesBoxName);
    await Hive.openBox(_foldersBoxName);
    await Hive.openBox(_settingsBoxName);
    _ensureDefaultCategory();
  }

  void _ensureDefaultCategory() {
    final cats = getTagCategories();
    if (!cats.any((c) => c.id == _defaultCategoryId)) {
      final defaultCat = TagCategory(
        id: _defaultCategoryId,
        name: 'Uncategorized',
        colorIndex: 0,
        iconIndex: 0,
        sortOrder: 9999, // Put at bottom by default
      );
      saveTagCategory(defaultCat);
    }
  }

  // --- UPDATED: Return sorted list ---
  List<TagCategory> getTagCategories() {
    final raw = _settingsBox.get(_tagCategoriesKey, defaultValue: []);
    if (raw is List) {
      final list = raw
          .map((e) {
            try {
              return TagCategory.fromJson(Map<String, dynamic>.from(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<TagCategory>()
          .toList();

      // Sort by sortOrder
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    }
    return [];
  }

  Future<void> saveTagCategory(TagCategory cat) async {
    String cleanName = cat.name.trim();
    if (cleanName.isNotEmpty) {
      cleanName = "${cleanName[0].toUpperCase()}${cleanName.substring(1)}";
    }

    // Get existing categories to determine sort order if new
    final cats = getTagCategories();
    final index = cats.indexWhere((c) => c.id == cat.id);

    // Preserve existing sort order if updating, else put at end
    int order = cat.sortOrder;
    if (index == -1 && order == 0) {
      // New Item: Set order to last
      order = cats.isNotEmpty ? (cats.last.sortOrder + 1) : 0;
    }

    final formattedCat = TagCategory(
      id: cat.id,
      name: cleanName,
      colorIndex: cat.colorIndex,
      iconIndex: cat.iconIndex,
      sortOrder: order,
    );

    if (index >= 0) {
      cats[index] = formattedCat;
    } else {
      cats.add(formattedCat);
    }

    // Sort before saving just in case
    cats.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    await _settingsBox.put(
      _tagCategoriesKey,
      cats.map((e) => e.toJson()).toList(),
    );
  }

  // --- NEW: REORDER LOGIC ---
  Future<void> reorderTagCategories(int oldIndex, int newIndex) async {
    final cats = getTagCategories();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = cats.removeAt(oldIndex);
    cats.insert(newIndex, item);

    // Update sortOrder for ALL items to match new index
    final updatedCats = <TagCategory>[];
    for (int i = 0; i < cats.length; i++) {
      final c = cats[i];
      updatedCats.add(
        TagCategory(
          id: c.id,
          name: c.name,
          colorIndex: c.colorIndex,
          iconIndex: c.iconIndex,
          sortOrder: i, // Reset order based on list position
        ),
      );
    }

    await _settingsBox.put(
      _tagCategoriesKey,
      updatedCats.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> deleteTagCategory(String catId) async {
    if (catId == _defaultCategoryId) return;
    final cats = getTagCategories();
    cats.removeWhere((c) => c.id == catId);
    await _settingsBox.put(
      _tagCategoriesKey,
      cats.map((e) => e.toJson()).toList(),
    );

    final mapping = getTagMapping();
    final keysToReset = mapping.entries
        .where((e) => e.value == catId)
        .map((e) => e.key)
        .toList();
    for (var k in keysToReset) {
      mapping[k] = _defaultCategoryId;
    }
    await _settingsBox.put(_tagMappingKey, mapping);
  }

  // ... [getTagColor, getTagMapping, setTagCategory etc. remain EXACTLY as they were in the previous working version] ...
  Map<String, String> getTagMapping() {
    final raw = _settingsBox.get(_tagMappingKey, defaultValue: {});
    return Map<String, String>.from(raw);
  }

  Future<void> setTagCategory(String tag, String categoryId) async {
    final mapping = getTagMapping();
    mapping[tag] = categoryId;
    await _settingsBox.put(_tagMappingKey, mapping);
  }

  Color getTagColor(String tag) {
    final cats = getTagCategories();
    if (cats.isEmpty) return CupertinoColors.systemGrey;
    final mapping = getTagMapping();
    final catId = mapping[tag] ?? _defaultCategoryId;
    final cat = cats.firstWhere(
      (c) => c.id == catId,
      orElse: () => cats.firstWhere(
        (c) => c.id == _defaultCategoryId,
        orElse: () => cats.first,
      ),
    );
    int idx = cat.colorIndex;
    if (idx < 0 || idx >= AppConstants.categoryColors.length) idx = 0;
    return AppConstants.categoryColors[idx];
  }

  // ... [Standard Operations: Box getters, getAllEntries, etc. Copy from previous stable file if needed] ...
  Box get _entriesBox => Hive.box(_entriesBoxName);
  Box get _foldersBox => Hive.box(_foldersBoxName);
  Box get _settingsBox => Hive.box(_settingsBoxName);

  List<AppEntry> getAllEntries() {
    final data = _entriesBox.values;
    return data
        .map((e) => AppEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  AppEntry createNewEntry() {
    final now = DateTime.now().toIso8601String();
    return AppEntry(
      id: _uuid.v4(),
      attributes: {'dateCreated': now, 'dateEdited': now},
    );
  }

  Future<void> saveEntry(AppEntry entry) async {
    entry.setAttribute('dateEdited', DateTime.now().toIso8601String());
    await _entriesBox.put(entry.id, entry.toJson());
    await _updateFoldersContainingEntry(entry);
  }

  Future<void> deleteEntry(String id) async => await _entriesBox.delete(id);

  List<AppFolder> getAllFolders() {
    final data = _foldersBox.values;
    return data
        .map((e) => AppFolder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  AppFolder createNewFolder() {
    final now = DateTime.now().toIso8601String();
    return AppFolder(
      id: _uuid.v4(),
      attributes: {
        'dateCreated': now,
        'lastAddedTo': now,
        'displayTags': <String>[],
      },
    );
  }

  Future<void> saveFolder(AppFolder folder) async =>
      await _foldersBox.put(folder.id, folder.toJson());
  Future<void> deleteFolder(String id) async => await _foldersBox.delete(id);

  Future<void> _updateFoldersContainingEntry(AppEntry entry) async {
    final rawTag = entry.getAttribute('tag');
    List<String> entryTags = [];
    if (rawTag is String)
      entryTags = [rawTag];
    else if (rawTag is List)
      entryTags = List<String>.from(rawTag);
    if (entryTags.isEmpty) return;

    final allFolders = getAllFolders();
    final now = DateTime.now().toIso8601String();
    for (var folder in allFolders) {
      if (folder.displayTags.any((t) => entryTags.contains(t))) {
        folder.setAttribute('lastAddedTo', now);
        await _foldersBox.put(folder.id, folder.toJson());
      }
    }
  }

  List<AppEntry> getEntriesForFolder(AppFolder folder) {
    final allEntries = getAllEntries();
    if (folder.displayTags.isEmpty) return [];
    return allEntries.where((entry) {
      final rawTag = entry.getAttribute('tag');
      if (rawTag == null) return false;
      List<String> entryTags = [];
      if (rawTag is String)
        entryTags = [rawTag];
      else if (rawTag is List)
        entryTags = List<String>.from(rawTag);
      return entryTags.any((t) => folder.displayTags.contains(t));
    }).toList();
  }

  List<String> getGlobalTags() =>
      _settingsBox
          .get(_globalTagsKey, defaultValue: <String>[])
          ?.cast<String>() ??
      [];

  Future<void> addGlobalTag(String tag) async {
    final currentTags = getGlobalTags();
    if (!currentTags.contains(tag)) {
      currentTags.add(tag);
      await _settingsBox.put(_globalTagsKey, currentTags);
      await setTagCategory(tag, _defaultCategoryId);
    }
  }

  // In lib/storage_service.dart

  Future<void> removeGlobalTag(String tag) async {
    // 1. Remove from Global List
    final currentTags = getGlobalTags();
    currentTags.remove(tag);
    await _settingsBox.put(_globalTagsKey, currentTags);

    // 2. Remove from Category Mapping
    final mapping = getTagMapping();
    mapping.remove(tag);
    await _settingsBox.put(_tagMappingKey, mapping);

    // 3. Remove from Folders (FIXED: This was missing)
    final allFolders = getAllFolders();
    for (var f in allFolders) {
      final List<String> tags = List.from(f.displayTags);
      if (tags.contains(tag)) {
        tags.remove(tag);
        f.setAttribute('displayTags', tags);
        await saveFolder(f);
      }
    }

    // 4. Remove from Entries (FIXED: This was missing)
    final allEntries = getAllEntries();
    for (var e in allEntries) {
      final rawVal = e.getAttribute('tag');
      List<String> tags = (rawVal is String)
          ? [rawVal]
          : (rawVal is List ? List<String>.from(rawVal) : []);

      if (tags.contains(tag)) {
        tags.remove(tag);
        e.setAttribute('tag', tags); // Save empty list or reduced list
        await saveEntry(e);
      }
    }
  }

  Future<void> renameGlobalTag(String oldTag, String newTag) async {
    if (oldTag == newTag) return;

    // 1. Update Folders (FIXED)
    final allFolders = getAllFolders();
    for (var f in allFolders) {
      // Get a mutable copy of the tags
      final List<String> tags = List.from(f.displayTags);

      if (tags.contains(oldTag)) {
        final index = tags.indexOf(oldTag);
        tags[index] = newTag; // Update the list

        // CRITICAL: Write the updated list back to the folder attributes
        f.setAttribute('displayTags', tags);
        await saveFolder(f);
      }
    }

    // 2. Update Entries
    final allEntries = getAllEntries();
    for (var e in allEntries) {
      final rawVal = e.getAttribute('tag');
      List<String> tags = (rawVal is String)
          ? [rawVal]
          : (rawVal is List ? List<String>.from(rawVal) : []);

      if (tags.contains(oldTag)) {
        final index = tags.indexOf(oldTag);
        tags[index] = newTag;
        e.setAttribute('tag', tags);
        await saveEntry(e);
      }
    }

    // 3. Update Global List & Mappings
    final currentTags = getGlobalTags();
    if (currentTags.contains(oldTag)) {
      final index = currentTags.indexOf(oldTag);
      currentTags[index] = newTag; // Update in place to preserve order
      await _settingsBox.put(_globalTagsKey, currentTags);

      final mapping = getTagMapping();
      if (mapping.containsKey(oldTag)) {
        final catId = mapping[oldTag]!;
        mapping.remove(oldTag);
        mapping[newTag] = catId;
        await _settingsBox.put(_tagMappingKey, mapping);
      }
    }
  }

  List<AppEntry> getUntaggedEntries() {
    return getAllEntries().where((entry) {
      final rawTag = entry.getAttribute('tag');
      if (rawTag == null) return true;
      if (rawTag is String) return rawTag.trim().isEmpty;
      if (rawTag is List) return rawTag.isEmpty;
      return true;
    }).toList();
  }

  List<String> getExpandedEntryAttributes() {
    final raw = _settingsBox.get(
      _expandedEntryAttributesKey,
      defaultValue: ['title', 'tag', 'dateCompleted'],
    );
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return ['title', 'tag', 'dateCompleted'];
  }

  Future<void> saveExpandedAttributes(List<String> keys) async {
    await _settingsBox.put(_expandedEntryAttributesKey, keys);
  }

  List<AttributeDefinition> getCustomAttributes() {
    final raw = _settingsBox.get(_customAttributesKey, defaultValue: []);
    if (raw is List) {
      return raw
          .map((e) {
            try {
              return AttributeDefinition.fromJson(Map<String, dynamic>.from(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<AttributeDefinition>()
          .toList();
    }
    return [];
  }

  Future<void> addCustomAttribute(AttributeDefinition attr) async {
    final list = getCustomAttributes();
    // Prevent duplicates
    if (list.any((e) => e.key == attr.key)) return;

    list.add(attr);
    await _settingsBox.put(
      _customAttributesKey,
      list.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> updateCustomAttribute(AttributeDefinition updatedAttr) async {
    final list = getCustomAttributes();
    final index = list.indexWhere((a) => a.key == updatedAttr.key);

    if (index != -1) {
      list[index] = updatedAttr; // Replace with new version
      await _settingsBox.put(
        _customAttributesKey,
        list.map((e) => e.toJson()).toList(),
      );
    }
  }

  Future<void> deleteCustomAttribute(String key) async {
    final list = getCustomAttributes();
    list.removeWhere((e) => e.key == key);
    await _settingsBox.put(
      _customAttributesKey,
      list.map((e) => e.toJson()).toList(),
    );
  }
}
