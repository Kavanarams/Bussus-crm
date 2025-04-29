import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'task_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

class AllActivitiesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final String objectType;
  final String objectName;

  const AllActivitiesScreen({
    super.key, 
    required this.activities,
    required this.objectType,
    required this.objectName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('All Activities'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.cardBackground,
            padding: EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  objectType.substring(0, 1).toUpperCase() + objectType.substring(1),
                  style: AppTextStyles.secondaryText,
                ),
                Text(
                  objectName,
                  style: AppTextStyles.subheading,
                ),
              ],
            ),
          ),
          Expanded(
            child: Card(
              margin: EdgeInsets.all(AppDimensions.spacingL),
              child: ListView.separated(
                itemCount: activities.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                // In AllActivitiesScreen build method:
              itemBuilder: (context, index) {
                final activity = activities[index];
                return InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailScreen(
                          taskId: activity['id'],
                        ),
                      ),
                    );
                    
                    // If task was deleted or updated, notify parent
                    if (result == true && Navigator.canPop(context)) {
                      Navigator.pop(context, true); // Tell DetailsScreen to refresh
                    }
                  },
                  child: _buildActivityListItem(context, activity),
                );
              },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityListItem(BuildContext context, Map<String, dynamic> activity) {
    return Container(
      padding: EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  activity['subject'] ?? 'No Subject',
                  style: AppTextStyles.cardTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingM, 
                  vertical: AppDimensions.spacingXs
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(activity['status']),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                ),
                child: Text(
                  activity['status'] ?? '',
                  style: AppTextStyles.statusBadge,
                ),
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingM),
          _buildDetailRow('Due Date', activity['due_date'] ?? 'N/A'),
          _buildDetailRow('Assigned To', activity['assigned_to'] ?? 'N/A'),
          if (activity['description'] != null && activity['description'].toString().isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppDimensions.spacingS),
                Text(
                  'Description:',
                  style: AppTextStyles.fieldLabel,
                ),
                SizedBox(height: AppDimensions.spacingXs),
                Text(
                  activity['description'],
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTextStyles.fieldLabel,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.fieldValue,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in progress':
        return AppColors.primary;
      case 'on hold':
        return AppColors.warning;
      case 'not started':
        return Colors.grey;
      case 'planned':
        return Colors.purple;
      case 'follow up':
        return Colors.teal;
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }
}