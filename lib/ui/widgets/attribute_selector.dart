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

    // 1. Create a Set of all valid keys for quick lookup
    final validKeys = widget.availableAttributes.map((a) => a.key).toSet();

    // 2. Filter the initial selection: Only keep keys that actually exist
    //    This removes "zombie" attributes that were deleted but still saved on the folder.
    final validInitialSelection = widget.initialSelection
        .where((key) => validKeys.contains(key))
        .toList();

    _checkedKeys = validInitialSelection.toSet();
    _orderedKeys = List.from(validInitialSelection);

    // 3. Add the rest of the available attributes to the end of the list
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

  void _toggleSelection(String key) {
    setState(() {
      if (_checkedKeys.contains(key)) {
        _checkedKeys.remove(key);
      } else {
        _checkedKeys.add(key);
      }
    });
    _notifyParent();
  }

  String _getLabel(String key) {
    // We can now safely assume the key exists because we filtered _orderedKeys in initState
    try {
      final def = widget.availableAttributes.firstWhere((a) => a.key == key);
      return def.label;
    } catch (e) {
      return ""; // Should not happen with the new filter logic
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Header ---
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,

            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  return Material(
                    elevation: 10,
                    color: Colors.transparent,
                    shadowColor: Colors.black.withOpacity(0.2),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },

            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final item = _orderedKeys.removeAt(oldIndex);
                _orderedKeys.insert(newIndex, item);
              });
              _notifyParent();
            },

            children: _orderedKeys.asMap().entries.map((entry) {
              final int index = entry.key;
              final String key = entry.value;
              final bool isSelected = _checkedKeys.contains(key);
              final bool isLast = index == _orderedKeys.length - 1;

              return Container(
                key: ValueKey(key),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _toggleSelection(key),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // --- Custom Square Checkbox ---
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? CupertinoColors.activeBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? CupertinoColors.activeBlue
                                      : CupertinoColors.systemGrey4,
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      CupertinoIcons.checkmark_alt,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),

                            const SizedBox(width: 12),

                            // --- Label ---
                            Expanded(
                              child: Text(
                                _getLabel(key),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? Colors.black
                                      : CupertinoColors.systemGrey,
                                  fontFamily: '.SF Pro Text',
                                  fontWeight: isSelected
                                      ? FontWeight.w400
                                      : FontWeight.normal,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),

                            // --- Instant Drag Handle ---
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                color: Colors.transparent,
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: const Icon(
                                  CupertinoIcons.bars,
                                  color: CupertinoColors.systemGrey3,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // --- Divider Line ---
                    if (!isLast)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 36,
                        color: Color(0xFFF0F0F0),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
