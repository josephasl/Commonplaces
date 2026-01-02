import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// --- COLORS ---
class AppColors {
  static const Color primary = Colors.black;
  static const Color active = CupertinoColors.activeBlue;
  static const Color destructive = CupertinoColors.destructiveRed;
  static const Color destructiveBg = Color(0xFFFFE5E5);

  static const Color background = Colors.white;
  static const Color groupedBackground = Color(0xFFF2F2F7); // iOS Grouped Grey
  static const Color inputBackground = CupertinoColors.systemGrey6;

  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Colors.grey;
  static Color textTertiary = Colors.grey.withOpacity(0.6);

  static const Color divider = Color(0xFFF0F0F0);
  static const Color border = Colors.grey;
}

// --- DIMENSIONS ---
class AppDimens {
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;

  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
}

// --- TEXT STYLES ---
class AppTextStyles {
  // Use a getter if you want to switch fonts dynamically, or static const if fixed.
  // Using '.SF Pro Text' as requested, but falling back to system font.
  static const String _fontFamily = '.SF Pro Text';

  static const TextStyle header = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
  );

  static const TextStyle subHeader = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: CupertinoColors.systemGrey,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
}

// --- DECORATIONS ---
class AppDecorations {
  static BoxDecoration card = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppDimens.radiusL),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration input = BoxDecoration(
    color: AppColors.inputBackground,
    borderRadius: BorderRadius.circular(8),
  );

  static BoxDecoration groupedItem = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(10),
  );
}
