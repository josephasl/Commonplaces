import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// --- SHARED SORT OPTION ---
enum SortOption {
  nameAsc,
  nameDesc,
  createdNewest,
  createdOldest,
  updatedNewest,
  countHighToLow,
  countLowToHigh,
}

// --- APP CONSTANTS ---
class AppConstants {
  static const List<Color> categoryColors = [
    CupertinoColors.systemGrey, // 0
    CupertinoColors.systemRed,
    CupertinoColors.systemOrange,
    CupertinoColors.systemYellow,
    CupertinoColors.systemGreen,
    CupertinoColors.systemTeal,
    CupertinoColors.systemBlue,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPurple,
    CupertinoColors.systemPink,
    Color(0xFF8B4513), // Brown
    Color(0xFF2F4F4F), // Dark Slate
  ];

  static const List<IconData> categoryIcons = [
    CupertinoIcons.tag_fill, // 0
    CupertinoIcons.book_fill,
    CupertinoIcons.briefcase_fill,
    CupertinoIcons.person_fill,
    CupertinoIcons.star_fill,
    CupertinoIcons.flag_fill,
    CupertinoIcons.music_note_2,
    CupertinoIcons.film_fill,
    CupertinoIcons.game_controller_solid,
    CupertinoIcons.heart_fill,
    CupertinoIcons.house_fill,
    CupertinoIcons.map_fill,
    CupertinoIcons.cart_fill,
    CupertinoIcons.money_dollar,
    CupertinoIcons.lightbulb_fill,
    CupertinoIcons.desktopcomputer,
  ];
}

// --- MODELS ---

class TagCategory {
  final String id;
  final String name;
  final int colorIndex;
  final int iconIndex;
  final int sortOrder;

  TagCategory({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.iconIndex,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'iconIndex': iconIndex,
    'sortOrder': sortOrder,
  };

  factory TagCategory.fromJson(Map<String, dynamic> json) {
    return TagCategory(
      id: json['id'],
      name: json['name'],
      colorIndex: json['colorIndex'] ?? 0,
      iconIndex: json['iconIndex'] ?? 0,
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class AppEntry {
  final String id;
  final Map<String, dynamic> attributes;
  AppEntry({required this.id, required this.attributes});

  dynamic getAttribute<T>(String key) => attributes[key];
  void setAttribute(String key, dynamic value) => attributes[key] = value;

  Map<String, dynamic> toJson() => {'id': id, 'attributes': attributes};

  factory AppEntry.fromJson(Map<String, dynamic> json) => AppEntry(
    id: json['id'],
    attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
  );
}

class AppFolder {
  final String id;
  final Map<String, dynamic> attributes;
  AppFolder({required this.id, required this.attributes});

  List<String> get displayTags {
    final raw = attributes['displayTags'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  // CONTROLS: Card Grid, Entry Screen
  List<String> get visibleAttributes {
    final raw = attributes['visibleAttributes'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    // Default: Just Tag and Notes (Title removed)
    return ['tag', 'notes'];
  }

  // CONTROLS: Add/Edit Form, Sort Options
  List<String> get activeAttributes {
    final raw = attributes['activeAttributes'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    // Default: Just Tag (Title removed)
    return ['tag'];
  }

  void setVisibleAttributes(List<String> attrs) =>
      attributes['visibleAttributes'] = attrs;

  void setActiveAttributes(List<String> attrs) =>
      attributes['activeAttributes'] = attrs;

  dynamic getAttribute<T>(String key) => attributes[key];
  void setAttribute(String key, dynamic value) => attributes[key] = value;

  Map<String, dynamic> toJson() => {'id': id, 'attributes': attributes};

  factory AppFolder.fromJson(Map<String, dynamic> json) => AppFolder(
    id: json['id'],
    attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
  );
}
