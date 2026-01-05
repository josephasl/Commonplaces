import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../app_styles.dart';
import '../../models.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool showClear;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = "Search...",
    this.onChanged,
    this.onClear,
    this.showClear = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: AppDecorations.searchField,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(CupertinoIcons.search, color: Colors.black54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          suffixIcon: showClear
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: onClear,
                )
              : null,
        ),
        style: AppTextStyles.body,
        onChanged: onChanged,
      ),
    );
  }
}

class AppIconPicker extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AppIconPicker({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(AppConstants.categoryIcons.length, (index) {
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelect(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.inputBackground
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
              ),
              child: Icon(
                AppConstants.categoryIcons[index],
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AppColorPicker extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AppColorPicker({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(AppConstants.categoryColors.length, (index) {
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onSelect(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppConstants.categoryColors[index],
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: AppColors.textPrimary, width: 3)
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AppFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;
  final int badgeCount;

  const AppFloatingButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.background,
    this.iconColor = AppColors.primary,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: AppDecorations.floatingShadow,
            ),
            child: Icon(icon, color: iconColor),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppTagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const AppTagChip({
    super.key,
    required this.label,
    required this.color,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Color.lerp(Colors.white, color, 0.2)
              : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimens.cornerRadiusLess),
          border: isActive
              ? Border.all(color: color)
              : Border.all(color: AppColors.border.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          "#$label",
          style: AppTextStyles.body.copyWith(
            color: isActive ? color : Colors.grey.shade800,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class AppPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  AppPageRoute({required this.builder})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = Curves.easeInOut;

          final entranceTween = Tween(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: curve));

          final exitTween = Tween(
            begin: Offset.zero,
            end: const Offset(-1.0, 0.0),
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(entranceTween),
            child: SlideTransition(
              position: secondaryAnimation.drive(exitTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
}
