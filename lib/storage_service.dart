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
  static const String _attributeSortOrderKey = 'attribute_sort_order';

  static const String _manageLibraryTabIndexKey = 'manage_library_tab_index';
  static const String _hasSeededDefaultsKey = 'has_seeded_defaults';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_entriesBoxName);
    await Hive.openBox(_foldersBoxName);
    await Hive.openBox(_settingsBoxName);

    _ensureDefaultCategory();
    await _ensureDefaultAttributes();
  }

  void _ensureDefaultCategory() {
    final cats = getTagCategories();
    if (!cats.any((c) => c.id == _defaultCategoryId)) {
      final defaultCat = TagCategory(
        id: _defaultCategoryId,
        name: 'Uncategorized',
        colorIndex: 0,
        iconIndex: 0,
        sortOrder: 9999,
      );
      saveTagCategory(defaultCat);
    }
  }

  // --- NEW: Create Default Custom Attributes & Set Order ---
  Future<void> _ensureDefaultAttributes() async {
    final bool hasSeeded = _settingsBox.get(
      _hasSeededDefaultsKey,
      defaultValue: false,
    );

    if (!hasSeeded) {
      // Only create if list is empty to avoid duplicates on re-install scenarios
      if (getCustomAttributes().isEmpty) {
        final titleAttr = AttributeDefinition(
          key: 'title_default',
          label: 'Title',
          type: AttributeValueType.text,
          applyType: AttributeApplyType.entriesOnly,
        );

        final notesAttr = AttributeDefinition(
          key: 'notes_default',
          label: 'Notes',
          type: AttributeValueType.text,
          applyType: AttributeApplyType.entriesOnly,
        );

        final imageAttr = AttributeDefinition(
          key: 'image_default',
          label: 'Image',
          type: AttributeValueType.image,
          applyType: AttributeApplyType.entriesOnly,
        );

        // Add them to storage
        await addCustomAttribute(titleAttr);
        await addCustomAttribute(notesAttr);
        await addCustomAttribute(imageAttr);

        // FORCE SPECIFIC DEFAULT ORDER
        // Image -> Title -> Notes -> Tag -> Date Edited -> Date Created
        final defaultOrder = [
          'image_default',
          'title_default',
          'notes_default',
          'tag',
          'dateEdited',
          'dateCreated',
        ];
        await saveAttributeSortOrder(defaultOrder);
      }

      // Mark as seeded so we don't overwrite user changes later
      await _settingsBox.put(_hasSeededDefaultsKey, true);
    }
  }

  // ... [Rest of the file remains standard] ...

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
    final cats = getTagCategories();
    final index = cats.indexWhere((c) => c.id == cat.id);
    int order = cat.sortOrder;
    if (index == -1 && order == 0) {
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
    cats.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _settingsBox.put(
      _tagCategoriesKey,
      cats.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> reorderTagCategories(int oldIndex, int newIndex) async {
    final cats = getTagCategories();
    if (oldIndex < newIndex) newIndex -= 1;
    final item = cats.removeAt(oldIndex);
    cats.insert(newIndex, item);
    final updatedCats = <TagCategory>[];
    for (int i = 0; i < cats.length; i++) {
      final c = cats[i];
      updatedCats.add(
        TagCategory(
          id: c.id,
          name: c.name,
          colorIndex: c.colorIndex,
          iconIndex: c.iconIndex,
          sortOrder: i,
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

  int getManageLibraryTabIndex() {
    final val = _settingsBox.get(_manageLibraryTabIndexKey, defaultValue: 0);
    if (val is int && val >= 0 && val <= 1) return val;
    return 0;
  }

  Future<void> saveManageLibraryTabIndex(int index) async {
    await _settingsBox.put(_manageLibraryTabIndexKey, index);
  }

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

  Future<void> removeGlobalTag(String tag) async {
    final currentTags = getGlobalTags();
    currentTags.remove(tag);
    await _settingsBox.put(_globalTagsKey, currentTags);

    final mapping = getTagMapping();
    mapping.remove(tag);
    await _settingsBox.put(_tagMappingKey, mapping);

    final allFolders = getAllFolders();
    for (var f in allFolders) {
      final List<String> tags = List.from(f.displayTags);
      if (tags.contains(tag)) {
        tags.remove(tag);
        f.setAttribute('displayTags', tags);
        await saveFolder(f);
      }
    }

    final allEntries = getAllEntries();
    for (var e in allEntries) {
      final rawVal = e.getAttribute('tag');
      List<String> tags = (rawVal is String)
          ? [rawVal]
          : (rawVal is List ? List<String>.from(rawVal) : []);

      if (tags.contains(tag)) {
        tags.remove(tag);
        e.setAttribute('tag', tags);
        await saveEntry(e);
      }
    }
  }

  Future<void> renameGlobalTag(String oldTag, String newTag) async {
    if (oldTag == newTag) return;
    final allFolders = getAllFolders();
    for (var f in allFolders) {
      final List<String> tags = List.from(f.displayTags);
      if (tags.contains(oldTag)) {
        final index = tags.indexOf(oldTag);
        tags[index] = newTag;
        f.setAttribute('displayTags', tags);
        await saveFolder(f);
      }
    }
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
    final currentTags = getGlobalTags();
    if (currentTags.contains(oldTag)) {
      final index = currentTags.indexOf(oldTag);
      currentTags[index] = newTag;
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
    if (list.any((e) => e.key == attr.key)) return;
    list.add(attr);
    await _settingsBox.put(
      _customAttributesKey,
      list.map((e) => e.toJson()).toList(),
    );
    // Append to sort order list
    final currentOrder = getAttributeSortOrder();
    currentOrder.add(attr.key);
    await saveAttributeSortOrder(currentOrder);
  }

  Future<void> updateCustomAttribute(AttributeDefinition updatedAttr) async {
    final list = getCustomAttributes();
    final index = list.indexWhere((a) => a.key == updatedAttr.key);
    if (index != -1) {
      list[index] = updatedAttr;
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
    final currentOrder = getAttributeSortOrder();
    currentOrder.remove(key);
    await saveAttributeSortOrder(currentOrder);
  }

  List<String> getAttributeSortOrder() {
    return _settingsBox
            .get(_attributeSortOrderKey, defaultValue: <String>[])
            ?.cast<String>() ??
        [];
  }

  Future<void> saveAttributeSortOrder(List<String> keys) async {
    await _settingsBox.put(_attributeSortOrderKey, keys);
  }

  List<AttributeDefinition> getSortedAttributeDefinitions() {
    final customAttrs = getCustomAttributes();
    final allDefs = getEntryAttributes(customAttrs);
    final savedOrder = getAttributeSortOrder();

    if (savedOrder.isEmpty) {
      return allDefs;
    }

    final orderMap = {
      for (var i = 0; i < savedOrder.length; i++) savedOrder[i]: i,
    };

    allDefs.sort((a, b) {
      final indexA = orderMap[a.key] ?? 9999;
      final indexB = orderMap[b.key] ?? 9999;
      return indexA.compareTo(indexB);
    });

    return allDefs;
  }
}
