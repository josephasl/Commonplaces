// attributes.dart

enum AttributeValueType { text, number, date, image, list }

enum AttributeApplyType { entriesOnly, foldersOnly, both }

class AttributeDefinition {
  final String key;
  final String label;
  final AttributeValueType type;
  final AttributeApplyType applyType;
  final bool isSystemField;

  const AttributeDefinition({
    required this.key,
    required this.label,
    required this.type,
    required this.applyType,
    this.isSystemField = false,
  });
}

// Helper: Get only attributes that can be shown on an Entry Form
List<AttributeDefinition> getEntryAttributes() {
  return attributeRegistry.values
      .where(
        (attr) =>
            attr.applyType == AttributeApplyType.entriesOnly ||
            attr.applyType == AttributeApplyType.both,
      )
      .toList();
}

const Map<String, AttributeDefinition> attributeRegistry = {
  // -------------------------------
  "image": AttributeDefinition(
    key: "image",
    label: "Image",
    type: AttributeValueType.image,
    applyType: AttributeApplyType.both,
  ),
  "title": AttributeDefinition(
    key: "title",
    label: "Title",
    type: AttributeValueType.text,
    applyType: AttributeApplyType.entriesOnly,
  ),
  "tag": AttributeDefinition(
    key: "tag",
    label: "Tag",
    type: AttributeValueType.text,
    applyType: AttributeApplyType.entriesOnly,
  ),

  // Folders use this single list to store their tags
  "displayTags": AttributeDefinition(
    key: "displayTags",
    label: "Folder Tags",
    type: AttributeValueType.list,
    applyType: AttributeApplyType.foldersOnly,
  ),

  "sortOrder": AttributeDefinition(
    key: "sortOrder",
    label: "Sort Order",
    type: AttributeValueType.text,
    applyType: AttributeApplyType.foldersOnly,
  ),
  "starRating": AttributeDefinition(
    key: "starRating",
    label: "Rating",
    type: AttributeValueType.number,
    applyType: AttributeApplyType.entriesOnly,
  ),
  "notes": AttributeDefinition(
    key: "notes",
    label: "Notes",
    type: AttributeValueType.text,
    applyType: AttributeApplyType.entriesOnly,
  ),

  "dateCompleted": AttributeDefinition(
    key: "dateCompleted",
    label: "Completed Date",
    type: AttributeValueType.date,
    applyType: AttributeApplyType.entriesOnly,
  ),

  // --- SYSTEM ATTRIBUTES ---
  "dateCreated": AttributeDefinition(
    key: "dateCreated",
    label: "Date Created",
    type: AttributeValueType.date,
    applyType: AttributeApplyType.both,
    isSystemField: true,
  ),
  "dateEdited": AttributeDefinition(
    key: "dateEdited",
    label: "Date Edited",
    type: AttributeValueType.date,
    applyType: AttributeApplyType.entriesOnly,
    isSystemField: true,
  ),
  "lastAddedTo": AttributeDefinition(
    key: "lastAddedTo",
    label: "Last Added To",
    type: AttributeValueType.date,
    applyType: AttributeApplyType.foldersOnly,
    isSystemField: true,
  ),
};
