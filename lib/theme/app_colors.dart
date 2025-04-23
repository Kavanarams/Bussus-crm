// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2196F3); // Blue
  static const Color primaryLight = Color(0xFF73BEF7);
  static const Color primaryLighter = Color(0xFF87CEEB);
  static const Color primaryDark = Color(0xFF0D47A1);
  
  // Background colors
  static const Color background = Color(0xFFE0F7FA);
  static const Color cardBackground = Colors.white;
  static const Color actionButtonBackground = Color(0xFFE3F2FD); // Light blue for circular action buttons
  
  // Text colors
  static const Color textPrimary = Color(0xFF070707);
  static const Color textSecondary = Color(0xFF191919);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textWhite = Colors.white;
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = primary;
  
  // Specific component colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color iconBlue = Color(0xFF2196F3);
  static const Color statusBadgeBg = Color(0xFFE3F2FD);
  static const Color statusBadgeText = Color(0xFF0D47A1);
}