import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class BaseBottomSheet extends StatefulWidget {
  final String title;
  final Widget child;
  final VoidCallback? onSave;
  final bool hideSave;

  const BaseBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.onSave,
    this.hideSave = false,
  });

  @override
  State<BaseBottomSheet> createState() => _BaseBottomSheetState();
}

class _BaseBottomSheetState extends State<BaseBottomSheet> {
  double _currentOffset = 0.0;
  bool _isDragging = false;

  void _onDragUpdate(DragUpdateDetails details) {
    // Only allow dragging downwards (positive delta)
    if (details.primaryDelta! > 0 || _currentOffset > 0) {
      setState(() {
        _isDragging = true;
        _currentOffset += details.primaryDelta!;
      });
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    // Dismiss if dragged down more than 150px OR flicked down fast
    if (_currentOffset > 150 || (details.primaryVelocity ?? 0) > 500) {
      Navigator.pop(context);
    } else {
      // Snap back to 0
      setState(() {
        _currentOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine bottom padding (Keyboard + safe area)
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: AnimatedContainer(
        // Animate snap-back, but be instant while dragging
        duration: Duration(milliseconds: _isDragging ? 0 : 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _currentOffset, 0),
        child: Container(
          // Dynamic Height: Fits content, but maxes out at 90% screen height
          constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
          decoration: const BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min, // Shrink to fit content
              children: [
                // --- DRAGGABLE HEADER ZONE ---
                GestureDetector(
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  behavior:
                      HitTestBehavior.opaque, // Catch touches on empty space
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Drag Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // 2. Header (Cancel / Title / Save)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Text("Cancel"),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            if (!widget.hideSave)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: widget.onSave,
                                child: const Text(
                                  "Save",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              const SizedBox(width: 50), // Balance spacing
                          ],
                        ),
                      ),
                      Container(height: 1, color: Colors.grey.shade200),
                    ],
                  ),
                ),

                // --- CONTENT ---
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    // Prevent ScrollView from blocking the drag if at top?
                    // Complex to do perfectly without packages,
                    // but the Header drag above covers 90% of use cases.
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        widget.child,
                        // --- EXTRA BOTTOM PADDING ---
                        const SafeArea(top: false, child: SizedBox(height: 40)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
