import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';

class AppInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isRequired;
  
  const AppInfoItem({
    super.key,
    required this.label,
    required this.value,
    this.isRequired = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label${isRequired ? ' *' : ''}",
            style: AppTextStyles.fieldLabel,
          ),
          Text(
            value,
            style: AppTextStyles.fieldValue,
          ),
        ],
      ),
    );
  }
}