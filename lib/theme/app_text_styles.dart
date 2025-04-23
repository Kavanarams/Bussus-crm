// lib/theme/app_text_styles.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppTextStyles {
  // Headings
  static const TextStyle heading = TextStyle(
    fontSize: AppDimensions.textHeading,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle subheading = TextStyle(
    fontSize: AppDimensions.textXxl,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  // Body text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: AppDimensions.textL,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: AppDimensions.textM,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: AppDimensions.textS,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w400,
  );
  
  // Secondary text (labels, hints)
  static const TextStyle secondaryText = TextStyle(
    fontSize: AppDimensions.textM,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w400,
  );
  
  static const TextStyle labelText = TextStyle(
    fontSize: AppDimensions.textS,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w400,
  );
  
  // Form field labels
  static const TextStyle fieldLabel = TextStyle(
    fontSize: AppDimensions.textM,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.normal,
  );
  
  static const TextStyle fieldValue = TextStyle(
    fontSize: AppDimensions.textM,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w500,
  );
  
  // Action text
  static const TextStyle actionText = TextStyle(
    fontSize: AppDimensions.textM,
    color: AppColors.primary,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle smallActionText = TextStyle(
    fontSize: AppDimensions.textXs,
    color: AppColors.primaryDark,
    fontWeight: FontWeight.w500,
  );
  
  // AppBar title
  static const TextStyle appBarTitle = TextStyle(
    color: AppColors.textWhite,
    fontSize: AppDimensions.textL,
    fontWeight: FontWeight.w600,
  );
  
  // Card title
  static const TextStyle cardTitle = TextStyle(
    fontSize: AppDimensions.textL,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  // Status badge
  static const TextStyle statusBadge = TextStyle(
    fontSize: AppDimensions.textXs,
    fontWeight: FontWeight.bold,
    color: AppColors.textWhite,
  );
}