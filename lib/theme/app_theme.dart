// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_decorations.dart';
import 'app_text_styles.dart';
import 'app_button_styles.dart';

class AppTheme {
  // Create the main theme for the app
  static ThemeData get lightTheme {
    final ThemeData base = ThemeData.light();
    
    return base.copyWith(
      // Colors
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        error: AppColors.error,
        background: AppColors.background,
        surface: AppColors.cardBackground,
      ),
      
      // Text theme
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.heading,
        displayMedium: AppTextStyles.subheading,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.actionText,
        labelMedium: AppTextStyles.labelText,
      ),
      
      // Component themes
      appBarTheme: AppDecorations.appBarTheme,
      cardTheme: AppDecorations.cardTheme,
      inputDecorationTheme: AppDecorations.inputDecorationTheme,
      
      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppButtonStyles.primaryButton,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonStyles.secondaryButton,
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppButtonStyles.textButton,
      ),
    
      
      // Visual density for all widgets
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}