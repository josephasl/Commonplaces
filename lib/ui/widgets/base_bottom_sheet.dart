import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../app_styles.dart';

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
    if (details.primaryDelta! > 0 || _currentOffset > 0) {
      setState(() {
        _isDragging = true;
        _currentOffset += details.primaryDelta!;
      });
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    if (_currentOffset > 150 || (details.primaryVelocity ?? 0) > 500) {
      Navigator.pop(context);
    } else {
      setState(() => _currentOffset = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isDragging ? 0 : 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _currentOffset, 0),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimens.cornerRadius),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            Text(widget.title, style: AppTextStyles.header),
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
                              const SizedBox(width: 50),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimens.paddingM),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        widget.child,
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
