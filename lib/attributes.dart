enum AttributeValueType { text, number, date, image, list, rating }

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

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'type': type.index,
    'applyType': applyType.index,
    'isSystemField': isSystemField,
  };

  factory AttributeDefinition.fromJson(Map<String, dynamic> json) {
    return AttributeDefinition(
      key: json['key'],
      label: json['label'],
      type: AttributeValueType.values[json['type']],
      applyType: AttributeApplyType.values[json['applyType']],
      isSystemField: json['isSystemField'] ?? false,
    );
  }
}

// 1. HARDCODED SYSTEM ATTRIBUTES
const Map<String, AttributeDefinition> _systemAttributes = {
  "tag": AttributeDefinition(
    key: "tag",
    label: "Tag",
    type: AttributeValueType.text,
    applyType: AttributeApplyType.entriesOnly,
    isSystemField: true,
  ),
  "displayTags": AttributeDefinition(
    key: "displayTags",
    label: "Folder Tags",
    type: AttributeValueType.list,
    applyType: AttributeApplyType.foldersOnly,
    isSystemField: true,
  ),
  "sortOrder": AttributeDefinition(
    key: "sortOrder",
    label: "Sort Order",
    type: AttributeValueType.text,
    applyType: AttributeApplyType.foldersOnly,
    isSystemField: true,
  ),
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

// 2. REGISTRY ACCESSOR
Map<String, AttributeDefinition> getAttributeRegistry(
  List<AttributeDefinition> customAttributes,
) {
  final Map<String, AttributeDefinition> registry = Map.from(_systemAttributes);
  for (var attr in customAttributes) {
    registry[attr.key] = attr;
  }
  return registry;
}

// Helper: Get attributes suitable for Entry Forms
List<AttributeDefinition> getEntryAttributes(
  List<AttributeDefinition> customAttributes,
) {
  final registry = getAttributeRegistry(customAttributes);
  return registry.values
      .where(
        (attr) =>
            attr.applyType == AttributeApplyType.entriesOnly ||
            attr.applyType == AttributeApplyType.both,
      )
      .toList();
}
