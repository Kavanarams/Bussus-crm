import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart'; // Import DataProvider
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';
import '../theme/app_decorations.dart';
import 'taskeditscreen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  
  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _taskDetails = {};
  String? _error;
  final bool _isEditing = false;
  final bool _debugMode = true;
  
  // Controllers for editing fields
  final Map<String, TextEditingController> _controllers = {};
  // Key for the More button to position popup menu
  final GlobalKey _moreButtonKey = GlobalKey();

  void _logDebug(String message) {
    if (_debugMode) {
      print('📌 DEBUG: $message');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadTaskDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final token = authProvider.token;

      // Check if token exists
      if (token.isEmpty) {
        setState(() {
          _error = 'Authentication required. Please log in.';
          _isLoading = false;
        });
        return;
      }

      // Use DataProvider to fetch task details
      final result = await dataProvider.fetchTaskDetails(widget.taskId, token);

      if (result['success']) {
        setState(() {
          _taskDetails = result['data'];
          _error = null;
          // Initialize controllers with current values
          _initControllers();
        });
      } else {
        setState(() {
          _error = result['error'];
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error occurred: $e';
      });
      print('❌ Error in _loadTaskDetails: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _initControllers() {
    // Initialize text controllers for each editable field
    _controllers['subject'] = TextEditingController(text: _taskDetails['subject'] ?? '');
    _controllers['due_date'] = TextEditingController(text: _taskDetails['due_date'] ?? '');
    _controllers['assigned_to'] = TextEditingController(text: _taskDetails['assigned_to'] ?? '');
    _controllers['status'] = TextEditingController(text: _taskDetails['status'] ?? '');
    _controllers['related_to'] = TextEditingController(text: _taskDetails['related_to'] ?? '');
    
    if (_taskDetails.containsKey('description')) {
      _controllers['description'] = TextEditingController(text: _taskDetails['description'] ?? '');
    }
  }
  
  void _navigateToEditTask() async {
    _logDebug('Navigating to edit task screen for task ID: ${widget.taskId}');
    
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskEditScreen(
            taskId: widget.taskId,
            taskDetails: _taskDetails,
          ),
        ),
      );
      
      _logDebug('Returned from edit task screen with result: $result');
      
      if (result == true) {
        _logDebug('Reloading task details');
        await _loadTaskDetails();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task details updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      _logDebug('Error navigating to edit screen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening edit screen: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
  
  void _showMoreOptionsDialog() {
    _logDebug('Show more options dialog called');
    
    try {
      // Check if context is valid
      if (_moreButtonKey.currentContext == null) {
        _logDebug('More button key context is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot show options menu'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      final RenderBox renderBox = _moreButtonKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      
      _logDebug('Showing menu at position: $position');
      
      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy + renderBox.size.height,
          position.dx + renderBox.size.width,
          position.dy + renderBox.size.height + 10,
        ),
        color: Colors.white,
        elevation: AppDimensions.elevationM,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        items: [
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: AppDimensions.iconM),
                SizedBox(width: AppDimensions.spacingS),
                Text('Mark Complete', style: AppTextStyles.actionText),
              ],
            ),
            onTap: () {
              // Need to use Future.delayed because menu is closing
              Future.delayed(Duration.zero, () {
                _markTaskComplete();
              });
            },
          ),
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary, size: AppDimensions.iconM),
                SizedBox(width: AppDimensions.spacingS),
                Text('Change Date', style: AppTextStyles.actionText),
              ],
            ),
            onTap: () {
              // Need to use Future.delayed because menu is closing
              Future.delayed(Duration.zero, () {
                _changeTaskDate();
              });
            },
          ),
        ],
      );
    } catch (e) {
      _logDebug('Error showing more options menu: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error showing options menu: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
  
  void _markTaskComplete() {
    _logDebug('Mark task complete called');
    
    try {
      // Implement your API call here to mark the task as complete
      // For now, show a placeholder message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marking task as complete...'),
          backgroundColor: AppColors.primary,
        ),
      );
      
      // In the real implementation, you would update the status and reload the task
    } catch (e) {
      _logDebug('Error marking task complete: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking task complete: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
  
  void _changeTaskDate() async {
    _logDebug('Change task date called');
    
    try {
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
      );
      
      _logDebug('Selected date: $pickedDate');
      
      if (pickedDate != null) {
        // Implement your API call here to change the task date
        // For now, show a placeholder message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Date change functionality will be implemented'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      _logDebug('Error changing task date: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error changing task date: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }


  Future<void> _deleteTask() async {
  _logDebug('Delete task function called for task ID: ${widget.taskId}');
  
  try {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        title: Text('Confirm Delete', style: AppTextStyles.cardTitle),
        content: Text('Are you sure you want to delete this task?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.dialogCancelButton,
            child: Text('Cancel', style: AppTextStyles.secondaryText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.dialogConfirmButton,
            child: Text('Delete', style: AppTextStyles.statusBadge),
          ),
        ],
      ),
    );

    _logDebug('Delete confirmation dialog result: $confirm');
    
    if (confirm == true) {
      _logDebug('Proceeding with delete');
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token.isEmpty) {
        throw Exception('Authentication token is empty');
      }
      
      _logDebug('Calling deleteTask method from DataProvider');
      
      final result = await dataProvider.deleteTask(widget.taskId, token);

      _logDebug('Delete result: $result');

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh the previous screen
      } else {
        String errorMessage = result['error'] ?? 'Failed to delete task';
        _logDebug('Error message: $errorMessage');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  } catch (e) {
    _logDebug('Error deleting task: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error deleting task: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search functionality coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications functionality coming soon')),
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: AppTextStyles.bodyMedium))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderWithActions(),
                      _buildTaskDetailsCard(),
                      // Add related activities section if available
                      if (_taskDetails.containsKey('related_activities'))
                        _buildRelatedActivitiesSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderWithActions() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with action icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              // Edit Icon
              _buildActionButton(
                icon: Icons.edit,
                label: 'Edit',
                onTap: _navigateToEditTask,
              ),
              
              // Delete Icon
              _buildActionButton(
                icon: Icons.delete,
                label: 'Delete',
                onTap: _deleteTask,
              ),
              
              // More Icon
              _buildActionButton(
                icon: Icons.more_horiz,
                label: 'More',
                onTap: _showMoreOptionsDialog,
                key: _moreButtonKey,
              ),
            ],
          ),
          
          SizedBox(height: AppDimensions.spacingM),
          
          // Task type
          Text(
            'Task',
            style: AppTextStyles.secondaryText,
          ),
          
          // Task subject
          Text(
            _taskDetails['subject'] ?? 'Task',
            style: AppTextStyles.heading,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXl),
      child: GestureDetector( // Use GestureDetector instead of just Column
        onTap: onTap, // Handle tap here
        child: Column(
          mainAxisSize: MainAxisSize.min,
          key: key,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.actionButtonBackground,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              ),
              padding: EdgeInsets.all(AppDimensions.spacingS),
              child: Icon(
                icon, 
                color: AppColors.primary, 
                size: AppDimensions.iconM,
              ),
            ),
            SizedBox(height: AppDimensions.spacingXs),
            Text(
              label, 
              style: AppTextStyles.smallActionText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskDetailsCard() {
    final displayFields = [
      {'label': 'Subject', 'field': 'subject'},
      {'label': 'Due Date', 'field': 'due_date'},
      {'label': 'Status', 'field': 'status'},
      {'label': 'Assigned To', 'field': 'assigned_to'},
      {'label': 'Related To', 'field': 'related_to'},
    ];
    
    // Add description if available
    if (_taskDetails.containsKey('description')) {
      displayFields.add({'label': 'Description', 'field': 'description'});
    }

    return Card(
      margin: EdgeInsets.all(AppDimensions.spacingL),
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: AppTextStyles.cardTitle,
            ),
            SizedBox(height: AppDimensions.spacingM),
            
            // Display all fields
            ...displayFields.map((field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem(
                    field['label']!,
                    _formatValue(_taskDetails[field['field']]),
                  ),
                  Divider(height: AppDimensions.spacingXl),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.fieldLabel,
          ),
          SizedBox(height: AppDimensions.spacingXs),
          Text(
            value,
            style: AppTextStyles.fieldValue,
          ),
        ],
      ),
    );
  }
  
  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';

    if (value is bool) {
      return value ? 'Yes' : 'No';
    } else if (value is Map) {
      return value.isEmpty ? 'N/A' : value.toString();
    } else if (value is List) {
      return value.isEmpty ? 'N/A' : value.join(', ');
    } else {
      return value.toString().isEmpty ? 'N/A' : value.toString();
    }
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
  
  Widget _buildRelatedActivitiesSection() {
    final activities = _taskDetails['related_activities'] as List? ?? [];
    
    return Card(
      margin: EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(AppDimensions.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Open Activities',
                      style: AppTextStyles.cardTitle,
                    ),
                    SizedBox(width: AppDimensions.spacingS),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingS, vertical: AppDimensions.spacingXxs),
                      decoration: BoxDecoration(
                        color: AppColors.statusBadgeBg,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                      ),
                      child: Text(
                        '${activities.length}',
                        style: TextStyle(
                          color: AppColors.statusBadgeText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          activities.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(AppDimensions.spacingM),
                  child: Text(
                    'No activities found',
                    style: AppTextStyles.secondaryText,
                  ),
                )
              : Column(
                  children: [
                    ListView.separated(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: activities.length > 2 ? 2 : activities.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _buildActivityItem(activity);
                      },
                    ),
                    
                    // Add "View All" button if there are more than 2 activities
                    if (activities.length > 2) ...[
                      Divider(height: 1),
                      InkWell(
                        onTap: () {
                          // Navigate to all activities screen (to be implemented)
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingM),
                          child: Center(
                            child: Text(
                              'View All',
                              style: AppTextStyles.actionText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ],
      ),
    );
  }
  
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL, vertical: AppDimensions.spacingXs),
      title: Text(
        activity['subject'] ?? 'No Subject',
        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
              Text(
                'Due Date: ',
                style: AppTextStyles.secondaryText,
              ),
              Text(
                '${activity['due_date'] ?? 'N/A'}',
                style: AppTextStyles.fieldValue,
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingXxs),
          Row(
            children: [
              Text(
                'Status: ',
                style: AppTextStyles.secondaryText,
              ),
              Text(
                '${activity['status'] ?? 'N/A'}',
                style: AppTextStyles.fieldValue,
              ),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM, vertical: AppDimensions.spacingXs),
        decoration: AppDecorations.getStatusBadgeDecoration(_getStatusColor(activity['status'])),
        child: Text(
          activity['status'] ?? '',
          style: AppTextStyles.statusBadge,
        ),
      ),
      onTap: () {
        // Navigate to task detail page for this activity
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(
              taskId: activity['id'],
            ),
          ),
        );
      },
    );
  }
}