import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

class AppStatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  
  const AppStatusBadge({
    Key? key,
    required this.status,
    required this.color,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Text(
        status,
        style: AppTextStyles.statusBadge,
      ),
    );
  }
}