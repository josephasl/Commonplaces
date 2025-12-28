import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

class StorageService {
  final Uuid _uuid = const Uuid();

  static const String _entriesBoxName = 'entries_box';
  static const String _foldersBoxName = 'folders_box';
  static const String _settingsBoxName = 'settings_box';

  // Keys for Settings
  static const String _globalTagsKey = 'global_tags';
  static const String _expandedEntryAttributesKey = 'expanded_entry_attributes';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_entriesBoxName);
    await Hive.openBox(_foldersBoxName);
    await Hive.openBox(_settingsBoxName);
  }

  // ==========================================
  // ENTRY OPERATIONS
  // ==========================================

  Box get _entriesBox => Hive.box(_entriesBoxName);

  List<AppEntry> getAllEntries() {
    final data = _entriesBox.values;
    return data.map((e) {
      final jsonMap = Map<String, dynamic>.from(e);
      return AppEntry.fromJson(jsonMap);
    }).toList();
  }

  /// Creates a blank entry with automatic timestamps
  AppEntry createNewEntry() {
    final now = DateTime.now().toIso8601String();
    return AppEntry(
      id: _uuid.v4(),
      attributes: {'dateCreated': now, 'dateEdited': now},
    );
  }

  /// Saves an entry and performs automatic updates:
  /// 1. Updates 'dateEdited' on the entry.
  /// 2. Updates 'lastAddedTo' on any Folder that includes this entry's tags.
  Future<void> saveEntry(AppEntry entry) async {
    // 1. Auto-update 'dateEdited'
    entry.setAttribute('dateEdited', DateTime.now().toIso8601String());

    // 2. Save the entry to Hive
    await _entriesBox.put(entry.id, entry.toJson());

    // 3. Update 'lastAddedTo' for relevant folders
    await _updateFoldersContainingEntry(entry);
  }

  Future<void> deleteEntry(String id) async {
    await _entriesBox.delete(id);
  }

  // ==========================================
  // FOLDER OPERATIONS
  // ==========================================

  Box get _foldersBox => Hive.box(_foldersBoxName);

  List<AppFolder> getAllFolders() {
    final data = _foldersBox.values;
    return data.map((e) {
      final jsonMap = Map<String, dynamic>.from(e);
      return AppFolder.fromJson(jsonMap);
    }).toList();
  }

  /// Creates a new folder with automatic timestamps
  AppFolder createNewFolder() {
    final now = DateTime.now().toIso8601String();
    return AppFolder(
      id: _uuid.v4(),
      attributes: {
        'dateCreated': now,
        'lastAddedTo': now, // Initially same as created
        'displayTags': <String>[],
      },
    );
  }

  Future<void> saveFolder(AppFolder folder) async {
    await _foldersBox.put(folder.id, folder.toJson());
  }

  Future<void> deleteFolder(String id) async {
    await _foldersBox.delete(id);
  }

  // ==========================================
  // INTERNAL HELPERS (Automatic Logic)
  // ==========================================

  /// Checks if any folder cares about the tags in this entry.
  /// If so, updates that folder's 'lastAddedTo' date.
  Future<void> _updateFoldersContainingEntry(AppEntry entry) async {
    // Get tags from entry safely
    final rawTag = entry.getAttribute('tag');
    List<String> entryTags = [];
    if (rawTag is String) {
      entryTags = [rawTag];
    } else if (rawTag is List) {
      entryTags = List<String>.from(rawTag);
    }

    if (entryTags.isEmpty) return;

    final allFolders = getAllFolders();
    final now = DateTime.now().toIso8601String();

    for (var folder in allFolders) {
      // Check for intersection: Does the folder filter for ANY of the entry's tags?
      final folderTags = folder.displayTags;
      bool isRelevant = folderTags.any((t) => entryTags.contains(t));

      if (isRelevant) {
        folder.setAttribute('lastAddedTo', now);
        // We use the internal put directly to avoid infinite recursion
        await _foldersBox.put(folder.id, folder.toJson());
      }
    }
  }

  // ==========================================
  // QUERY HELPER
  // ==========================================

  List<AppEntry> getEntriesForFolder(AppFolder folder) {
    final allEntries = getAllEntries();
    final folderTags = folder.displayTags;

    if (folderTags.isEmpty) return [];

    return allEntries.where((entry) {
      final rawTag = entry.getAttribute('tag');
      if (rawTag == null) return false;

      List<String> entryTags = [];
      if (rawTag is String) {
        entryTags = [rawTag];
      } else if (rawTag is List) {
        entryTags = List<String>.from(rawTag);
      }

      return entryTags.any((t) => folderTags.contains(t));
    }).toList();
  }

  // ==========================================
  // SETTINGS & TAG OPERATIONS
  // ==========================================

  Box get _settingsBox => Hive.box(_settingsBoxName);

  List<String> getGlobalTags() {
    return _settingsBox
            .get(_globalTagsKey, defaultValue: <String>[])
            ?.cast<String>() ??
        [];
  }

  Future<void> addGlobalTag(String tag) async {
    final currentTags = getGlobalTags();
    if (!currentTags.contains(tag)) {
      currentTags.add(tag);
      await _settingsBox.put(_globalTagsKey, currentTags);
    }
  }

  Future<void> removeGlobalTag(String tag) async {
    final currentTags = getGlobalTags();
    currentTags.remove(tag);
    await _settingsBox.put(_globalTagsKey, currentTags);
  }

  Future<void> renameGlobalTag(String oldTag, String newTag) async {
    if (oldTag == newTag) return;

    // 1. Update all Folders that use this tag
    final allFolders = getAllFolders();
    for (var folder in allFolders) {
      final displayTags = folder.displayTags;
      if (displayTags.contains(oldTag)) {
        final tagIndex = displayTags.indexOf(oldTag);
        displayTags[tagIndex] = newTag;
        folder.setAttribute('displayTags', displayTags);
        await saveFolder(folder);
      }
    }

    // 2. Update all Entries that use this tag
    final allEntries = getAllEntries();
    for (var entry in allEntries) {
      final rawVal = entry.getAttribute('tag');
      List<String> tags = [];
      if (rawVal is String) {
        tags = [rawVal];
      } else if (rawVal is List) {
        tags = List<String>.from(rawVal);
      }

      if (tags.contains(oldTag)) {
        final index = tags.indexOf(oldTag);
        tags[index] = newTag;
        entry.setAttribute('tag', tags);
        await saveEntry(entry);
      }
    }

    // 3. Update the Global List (Move to end to represent "Edit Date")
    final currentTags = getGlobalTags();
    if (currentTags.contains(oldTag)) {
      currentTags.remove(oldTag); // Remove from old position
      currentTags.add(newTag); // Add to end (Newest)
      await _settingsBox.put(_globalTagsKey, currentTags);
    }
  }

  List<AppEntry> getUntaggedEntries() {
    final allEntries = getAllEntries();
    return allEntries.where((entry) {
      final rawTag = entry.getAttribute('tag');
      if (rawTag == null) return true;
      if (rawTag is String) return rawTag.trim().isEmpty;
      if (rawTag is List) return rawTag.isEmpty;
      return true;
    }).toList();
  }

  // ==========================================
  // UI PREFERENCES (Expansion States)
  // ==========================================

  List<String> getExpandedEntryAttributes() {
    final dynamic rawData = _settingsBox.get(
      _expandedEntryAttributesKey,
      defaultValue: ['title', 'tag', 'dateCompleted'],
    );

    if (rawData is List) {
      return rawData.map((e) => e.toString()).toList();
    }
    return ['title', 'tag', 'dateCompleted'];
  }

  Future<void> saveExpandedAttributes(List<String> keys) async {
    await _settingsBox.put(_expandedEntryAttributesKey, keys);
  }

  // ==========================================
  // DEV TOOLS
  // ==========================================

  Future<void> clearAllData() async {
    await _entriesBox.clear();
    await _foldersBox.clear();
  }
}
