import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../attributes.dart';

class AttributeSelector extends StatefulWidget {
  final List<String> initialSelection;
  final List<AttributeDefinition> availableAttributes;
  final Function(List<String>) onChanged;

  const AttributeSelector({
    super.key,
    required this.initialSelection,
    required this.availableAttributes,
    required this.onChanged,
  });

  @override
  State<AttributeSelector> createState() => _AttributeSelectorState();
}

class _AttributeSelectorState extends State<AttributeSelector> {
  late List<String> _orderedKeys;
  late Set<String> _checkedKeys;

  @override
  void initState() {
    super.initState();
    _checkedKeys = widget.initialSelection.toSet();
    _orderedKeys = List.from(widget.initialSelection);

    for (var attr in widget.availableAttributes) {
      if (!_orderedKeys.contains(attr.key)) {
        _orderedKeys.add(attr.key);
      }
    }
  }

  void _notifyParent() {
    final finalSelection = _orderedKeys
        .where((k) => _checkedKeys.contains(k))
        .toList();
    widget.onChanged(finalSelection);
  }

  @override
  Widget build(BuildContext context) {
    String getLabel(String key) {
      final def = widget.availableAttributes.firstWhere(
        (a) => a.key == key,
        orElse: () => AttributeDefinition(
          key: key,
          label: key,
          type: AttributeValueType.text,
          applyType: AttributeApplyType.entriesOnly,
        ),
      );
      return def.label;
    }

    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      header: const Padding(
        padding: EdgeInsets.only(bottom: 8.0, left: 4),
        child: Text(
          "Drag to reorder. Uncheck to hide.",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) newIndex -= 1;
          final item = _orderedKeys.removeAt(oldIndex);
          _orderedKeys.insert(newIndex, item);
        });
        _notifyParent();
      },
      children: _orderedKeys.map((key) {
        final isChecked = _checkedKeys.contains(key);

        return Material(
          key: ValueKey(key),
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: CupertinoColors.activeBlue,
            title: Text(
              getLabel(key),
              style: TextStyle(
                color: isChecked ? Colors.black : Colors.grey,
                fontWeight: isChecked ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            value: isChecked,
            secondary: const Icon(Icons.drag_handle, color: Colors.grey),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (bool? val) {
              setState(() {
                if (val == true) {
                  _checkedKeys.add(key);
                } else {
                  _checkedKeys.remove(key);
                }
              });
              _notifyParent();
            },
          ),
        );
      }).toList(),
    );
  }
}
