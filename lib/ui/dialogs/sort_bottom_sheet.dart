import 'package:flutter/cupertino.dart';
import '../app_styles.dart';

class SortOptionItem {
  final String key;
  final String label;

  const SortOptionItem(this.key, this.label);
}

class SortResult {
  final String key;
  final bool isAscending;

  const SortResult(this.key, this.isAscending);
}

Future<SortResult?> showUnifiedSortSheet({
  required BuildContext context,
  required String title,
  required List<SortOptionItem> options,
  required String currentSortKey,
  required bool currentIsAscending,
}) {
  return showCupertinoModalPopup<SortResult>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title, style: AppTextStyles.subHeader),
      message: const Text(
        "Tap the same option again to reverse order",
        style: AppTextStyles.caption,
      ),
      actions: options.map((item) {
        final isSelected = item.key == currentSortKey;

        // Determine the icon and direction for the next tap
        IconData? icon;
        if (isSelected) {
          icon = currentIsAscending
              ? CupertinoIcons.arrow_up
              : CupertinoIcons.arrow_down;
        }

        return CupertinoActionSheetAction(
          onPressed: () {
            // Logic: If clicking the same key, toggle direction.
            // If clicking a new key, default to Ascending (true)
            // UNLESS it's a date/number/count, where you usually want descending first.
            // However, to keep it simple and predictable per your request:
            // We just toggle if selected, reset to true (Asc) if new.
            // You can customize the "default for new key" logic here if preferred.

            bool nextAscending = true;

            if (isSelected) {
              nextAscending = !currentIsAscending;
            } else {
              // OPTIONAL: Smart defaults based on key names
              // If it's a date or count, usually users want Descending (High->Low) first
              if (item.key.toLowerCase().contains('date') ||
                  item.key.toLowerCase().contains('count') ||
                  item.key.toLowerCase().contains('last')) {
                nextAscending = false;
              } else {
                nextAscending = true;
              }
            }

            Navigator.of(ctx).pop(SortResult(item.key, nextAscending));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                style: AppTextStyles.body.copyWith(
                  color: isSelected ? AppColors.active : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: AppColors.active),
              ],
            ],
          ),
        );
      }).toList(),
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(ctx).pop(null),
        child: const Text("Cancel"),
      ),
    ),
  );
}
