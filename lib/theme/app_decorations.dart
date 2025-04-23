// lib/theme/app_decorations.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_text_styles.dart';
import 'package:flutter/services.dart'; // Add this import

class AppDecorations {
  // Card decoration
  static final CardTheme cardTheme = CardTheme(
    color: AppColors.cardBackground,
    elevation: AppDimensions.elevationM,
    margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
    ),
  );
  
  // Input field decoration
  static final InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppDimensions.spacingL,
      vertical: AppDimensions.spacingM,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      borderSide: BorderSide(color: AppColors.error),
    ),
    hintStyle: TextStyle(color: AppColors.textHint),
  );
  
  // App bar decoration
  static const AppBarTheme appBarTheme = AppBarTheme(
    backgroundColor: AppColors.primary,
    elevation: 0,
    centerTitle: false,
    foregroundColor: Colors.white,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: AppTextStyles.appBarTitle,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryLighter,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Status badge decoration
  static BoxDecoration getStatusBadgeDecoration(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
  );
  
  // Circle avatar for action buttons
  static const BoxDecoration circleButtonDecoration = BoxDecoration(
    color: AppColors.actionButtonBackground,
    shape: BoxShape.circle,
  );
}