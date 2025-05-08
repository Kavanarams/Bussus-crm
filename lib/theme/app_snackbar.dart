import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppSnackBar {
  // Keep this for backward compatibility with existing code
  static const SnackBarBehavior snackBarBehavior = SnackBarBehavior.fixed;
  static const Duration duration = Duration(seconds: 3);
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;
  
  // Method to show custom snackbar at the top
  static void _showCustomSnackBar(
    BuildContext context,
    String message,
    Color backgroundColor,
    Duration customDuration,
  ) {
    // If a snackbar is already visible, remove it first
    if (_isVisible) {
      _overlayEntry?.remove();
      _isVisible = false;
    }

    // Get screen size and safe area
    final mediaQuery = MediaQuery.of(context);
    final double topPadding = mediaQuery.padding.top;
    final double screenWidth = mediaQuery.size.width;
    
    // Create overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: topPadding + 8, // Position below status bar
        width: screenWidth - 80, // Full width with 8px margins on each side
        left: 50, // Left margin
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(4),
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    _overlayEntry?.remove();
                    _isVisible = false;
                  },
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Show the overlay
    Overlay.of(context).insert(_overlayEntry!);
    _isVisible = true;

    // Auto dismiss after duration
    Future.delayed(customDuration, () {
      if (_isVisible) {
        _overlayEntry?.remove();
        _isVisible = false;
      }
    });
  }

  // Create and show a success snackbar
  static void showSuccess(BuildContext context, String message, {Duration? customDuration}) {
    _showCustomSnackBar(
      context,
      message,
      AppColors.success,
      customDuration ?? duration,
    );
  }

  // Create and show an error snackbar
  static void showError(BuildContext context, String message, {Duration? customDuration}) {
    _showCustomSnackBar(
      context,
      message,
      AppColors.error,
      customDuration ?? duration,
    );
  }

  // Create and show a warning snackbar
  static void showWarning(BuildContext context, String message, {Duration? customDuration}) {
    _showCustomSnackBar(
      context,
      message,
      AppColors.warning,
      customDuration ?? duration,
    );
  }

  // Create and show an info snackbar
  static void showInfo(BuildContext context, String message, {Duration? customDuration}) {
    _showCustomSnackBar(
      context,
      message,
      AppColors.info,
      customDuration ?? duration,
    );
  }

  // For backward compatibility - these methods use the standard SnackBar at the bottom
  static SnackBar success({
    required String message,
    Duration? customDuration,
  }) {
    return SnackBar(
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: AppColors.success,
      duration: customDuration ?? duration,
      behavior: snackBarBehavior,
    );
  }
  
  static SnackBar error({
    required String message,
    Duration? customDuration,
  }) {
    return SnackBar(
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: AppColors.error,
      duration: customDuration ?? duration,
      behavior: snackBarBehavior,
    );
  }
  
  static SnackBar warning({
    required String message,
    Duration? customDuration,
  }) {
    return SnackBar(
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: AppColors.warning,
      duration: customDuration ?? duration,
      behavior: snackBarBehavior,
    );
  }
  
  static SnackBar info({
    required String message, 
    Duration? customDuration,
  }) {
    return SnackBar(
      content: Text(
        message, 
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: AppColors.info,
      duration: customDuration ?? duration,
      behavior: snackBarBehavior,
    );
  }
  
  // Original helper method for standard bottom SnackBar
  static void show(BuildContext context, SnackBar snackBar) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}