// --- SHARED SORT OPTION ---
enum SortOption {
  nameAsc,
  nameDesc,
  createdNewest,
  createdOldest,
  updatedNewest, // "Last Added To"
  countHighToLow,
  countLowToHigh,
}

class AppEntry {
  final String id;
  final Map<String, dynamic> attributes;

  AppEntry({required this.id, required this.attributes});

  // FIXED: Added <T> to allow generic calls
  dynamic getAttribute<T>(String key) => attributes[key];

  void setAttribute(String key, dynamic value) => attributes[key] = value;

  Map<String, dynamic> toJson() => {'id': id, 'attributes': attributes};

  factory AppEntry.fromJson(Map<String, dynamic> json) {
    return AppEntry(
      id: json['id'],
      attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
    );
  }
}

class AppFolder {
  final String id;
  final Map<String, dynamic> attributes;

  AppFolder({required this.id, required this.attributes});

  // 1. Single List of Tags
  List<String> get displayTags {
    final raw = attributes['displayTags'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  // 2. Attributes visible on entries INSIDE this folder
  List<String> get visibleAttributes {
    final raw = attributes['visibleAttributes'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return ['title', 'tag', 'notes']; // Default fallback
  }

  void setVisibleAttributes(List<String> attrs) {
    attributes['visibleAttributes'] = attrs;
  }

  // Generic getter
  dynamic getAttribute<T>(String key) => attributes[key];

  void setAttribute(String key, dynamic value) => attributes[key] = value;

  Map<String, dynamic> toJson() => {'id': id, 'attributes': attributes};

  factory AppFolder.fromJson(Map<String, dynamic> json) {
    return AppFolder(
      id: json['id'],
      attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
    );
  }
}
