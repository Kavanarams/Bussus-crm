// lib/theme/app_button_styles.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppButtonStyles {
  // Primary filled button
  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, AppDimensions.buttonHeight),
    padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
    ),
    elevation: AppDimensions.elevationM,
    textStyle: TextStyle(
      fontSize: AppDimensions.textM,
      fontWeight: FontWeight.w600,
    ),
  );
  
  // Secondary outlined button
  static final ButtonStyle secondaryButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: Size(double.infinity, AppDimensions.buttonHeight),
    padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
    side: BorderSide(color: AppColors.primary, width: 1),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.buttonBorderRadius),
    ),
    textStyle: TextStyle(
      fontSize: AppDimensions.textM,
      fontWeight: FontWeight.w600,
    ),
  );
  
  // Text button
  static final ButtonStyle textButton = TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM),
    textStyle: TextStyle(
      fontSize: AppDimensions.textM,
      fontWeight: FontWeight.w600,
    ),
  );
  
  // Dialog rounded buttons
  static final ButtonStyle dialogCancelButton = TextButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    backgroundColor: Colors.white,
    padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL, vertical: AppDimensions.spacingS),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      side: BorderSide(color: AppColors.divider),
    ),
  );
  
  static final ButtonStyle dialogConfirmButton = TextButton.styleFrom(
    foregroundColor: AppColors.textWhite,
    backgroundColor: AppColors.primary,
    padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL, vertical: AppDimensions.spacingS),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
    ),
  );
  
  // Icon buttons (for circular action buttons)
  static const double actionButtonSize = 32.0; // Diameter
  
  static final ButtonStyle circleIconButton = IconButton.styleFrom(
    padding: EdgeInsets.zero,
    backgroundColor: AppColors.actionButtonBackground,
    foregroundColor: AppColors.primary,
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}