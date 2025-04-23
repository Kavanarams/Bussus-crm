import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

class AppActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  
  const AppActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: AppDimensions.circleRadius,
          backgroundColor: AppColors.actionButtonBackground,
          child: IconButton(
            icon: Icon(icon, color: AppColors.primary, size: AppDimensions.iconS),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: AppDimensions.spacingXxs),
        Text(label, style: AppTextStyles.smallActionText),
      ],
    );
  }
}