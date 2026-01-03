import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// --- COLORS ---
class AppColors {
  static const Color primary = Colors.black;
  static const Color active = CupertinoColors.activeBlue;
  static const Color destructive = CupertinoColors.destructiveRed;
  static const Color destructiveBg = Color(0xFFFFE5E5);

  static const Color background = Colors.white;

  static const Color coloredBackground = Color(0xFFF2F2F7); // iOS Grouped Grey
  static const Color inputBackground = CupertinoColors.systemGrey6;
  static const Color untaggedBackground = Color.fromARGB(255, 218, 218, 223);

  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Colors.grey;
  static Color textTertiary = Colors.grey.withOpacity(0.6);

  static const Color divider = Color(0xFFF0F0F0);
  static const Color border = Colors.grey;
}

// --- DIMENSIONS ---
class AppDimens {
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double paddingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  static const double cornerRadius = 32.0;
  static const double cornerRadiusLess = 12.0;
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
    fontSize: 14,
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

  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,

    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: CupertinoColors.systemGrey,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  // --- CARD SPECIFIC STYLES ---

  static const TextStyle cardBody = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    color: Color(0xFF616161), // Colors.grey.shade700
    fontWeight: FontWeight.normal,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
  );

  static const TextStyle countLabel = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );
}

// --- DECORATIONS ---
class AppDecorations {
  static BoxDecoration card = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
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
    borderRadius: BorderRadius.circular(AppDimens.cornerRadiusLess),
  );

  static BoxDecoration groupedItem = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
  );

  static BoxDecoration searchField = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1), // Standard shadow
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

// --- SHADERS ---
class AppShaders {
  static ShaderCallback maskFadeRight = (Rect bounds) {
    return const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Colors.white, Colors.white, Colors.transparent],
      stops: [0.0, 0.9, .98],
    ).createShader(bounds);
  };
}
