import 'package:flutter/material.dart';
import '../app_styles.dart';

class AppSlidingSegmentedControl<T> extends StatelessWidget {
  final T groupValue;
  final Map<T, String> children;
  final ValueChanged<T> onValueChanged;

  const AppSlidingSegmentedControl({
    super.key,
    required this.groupValue,
    required this.children,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final values = children.keys.toList();
    final index = values.indexOf(groupValue);
    final count = values.length;

    // Alignment calculation: -1.0 is far left, 1.0 is far right.
    double alignX = 0.0;
    if (count > 1) {
      alignX = -1.0 + (2.0 * index / (count - 1));
    }

    return Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
      ),
      child: Stack(
        children: [
          if (index != -1)
            AnimatedAlign(
              alignment: Alignment(alignX, 0.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: values.map((val) {
              final isSelected = groupValue == val;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onValueChanged(val),
                  child: Center(
                    child: Text(
                      children[val]!,
                      style: AppTextStyles.subHeader.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
