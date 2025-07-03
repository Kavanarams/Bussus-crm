import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart'; 
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';
import '../theme/app_snackbar.dart';

class TaskEditScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskDetails;

  const TaskEditScreen({
    super.key,
    required this.taskId,
    required this.taskDetails,
  });

  @override
  _TaskEditScreenState createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final bool _isLoading = false;
  bool _isSaving = false;
  bool _isLoadingUsers = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  
  // Controllers for editing fields
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();
  final TextEditingController relatedToController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  
  String selectedStatus = 'Not Started';
  DateTime? selectedDate;
  String? selectedUserId;
  String? selectedUserName;
  
  // Error state variables
  Map<String, bool> fieldErrors = {
    'subject': false,
    'dueDate': false,
    'assignedTo': false,
  };

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _fetchUsers();
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    subjectController.dispose();
    dueDateController.dispose();
    relatedToController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token.isEmpty) {
        setState(() {
          _isLoadingUsers = false;
          _error = 'Authentication required to fetch users. Please log in.';
        });
        return;
      }
      
      // Get users from your data provider
      final result = await dataProvider.getUsers(token);
      
      if (result['success']) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(result['data']);
          _isLoadingUsers = false;
          
          // Try to find the assigned user in different ways
          _setSelectedUserFromTaskDetails();
        });
      } else {
        setState(() {
          _isLoadingUsers = false;
          _error = 'Failed to load users: ${result['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
        _error = 'Error loading users: $e';
      });
    }
  }
  
  void _setSelectedUserFromTaskDetails() {
    // Check different ways the assigned user might be stored
    if (_users.isEmpty) return;
    
    // Try to match by various possible identifiers
    int? userId;
    String? userEmail;
    String? userName;
    
    // Look for assigned_to_id first (most reliable)
    if (widget.taskDetails.containsKey('assigned_to_id') && 
        widget.taskDetails['assigned_to_id'] != null) {
      userId = widget.taskDetails['assigned_to_id'] is String 
          ? int.tryParse(widget.taskDetails['assigned_to_id'])
          : widget.taskDetails['assigned_to_id'];
    }
    
    // Look for email in assigned_to field
    if (widget.taskDetails.containsKey('assigned_to') && 
        widget.taskDetails['assigned_to'] != null &&
        widget.taskDetails['assigned_to'].toString().contains('@')) {
      userEmail = widget.taskDetails['assigned_to'];
    }
    
    // Look for name in assigned_to or assigned_to_name
    if (widget.taskDetails.containsKey('assigned_to_name') && 
        widget.taskDetails['assigned_to_name'] != null) {
      userName = widget.taskDetails['assigned_to_name'];
    } else if (widget.taskDetails.containsKey('assigned_to') && 
        widget.taskDetails['assigned_to'] != null &&
        !widget.taskDetails['assigned_to'].toString().contains('@')) {
      userName = widget.taskDetails['assigned_to'];
    }
    
    // Try to find matching user by ID first (most precise)
    if (userId != null) {
      final userMatch = _users.firstWhere(
        (user) => user['id'] == userId || user['id'].toString() == userId.toString(),
        orElse: () => {},
      );
      
      if (userMatch.isNotEmpty) {
        selectedUserId = userMatch['id'].toString();
        selectedUserName = userMatch['name'];
        return;
      }
    }
    
    // Try by email next
    if (userEmail != null) {
      final userMatch = _users.firstWhere(
        (user) => user['email'] == userEmail,
        orElse: () => {},
      );
      
      if (userMatch.isNotEmpty) {
        selectedUserId = userMatch['id'].toString();
        selectedUserName = userMatch['name'];
        return;
      }
    }
    
    // Finally try by name
    if (userName != null) {
      final userMatch = _users.firstWhere(
        (user) => user['name'] == userName,
        orElse: () => {},
      );
      
      if (userMatch.isNotEmpty) {
        selectedUserId = userMatch['id'].toString();
        selectedUserName = userMatch['name'];
        return;
      }
    }
    
    // Debug print all the possibilities we tried
    print('⚠️ Could not find matching user for task:');
    print('🆔 Attempted ID: $userId');
    print('📧 Attempted Email: $userEmail');
    print('👤 Attempted Name: $userName');
    print('📋 Available Users: ${_users.map((u) => "${u['id']}: ${u['name']} (${u['email']})").join(', ')}');
    print('🔍 Task Details: ${widget.taskDetails}');
  }
  
  void _initializeControllers() {
    // Initialize text controllers with values from taskDetails
    subjectController.text = widget.taskDetails['subject'] ?? '';
    dueDateController.text = widget.taskDetails['due_date'] ?? '';
    relatedToController.text = widget.taskDetails['related_to'] ?? '';
    descriptionController.text = widget.taskDetails['description'] ?? '';
    
    // Initialize status
    selectedStatus = widget.taskDetails['status'] ?? 'Not Started';
    
    // Parse date if available
    if (widget.taskDetails['due_date'] != null && widget.taskDetails['due_date'].isNotEmpty) {
      try {
        List<String> dateParts = widget.taskDetails['due_date'].split('-');
        if (dateParts.length == 3) {
          selectedDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
        }
      } catch (e) {
        print('Error parsing date: $e');
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2025, 12, 31),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textWhite,
              onSurface: AppColors.textPrimary,
              surface: AppColors.cardBackground,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dueDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        fieldErrors['dueDate'] = false;
      });
    }
  }

  void showTopSnackBar({required String message, required Color backgroundColor}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Add this method to _TaskEditScreenState class to debug and ensure we have the right related_to_id
void _debugOriginalTaskDetails() {
  print('👉 ORIGINAL TASK DETAILS:');
  print('📎 related_to_id: ${widget.taskDetails['related_to_id']}');
  print('📎 related_to: ${widget.taskDetails['related_to']}');
  print('📎 All fields: ${widget.taskDetails}');
}

// Replace the _saveTask method with this implementation
// Updated _saveTask method with minimal data
Future<void> _saveTask() async {
  // Debug the original task data first
  _debugOriginalTaskDetails();

  // Check for required fields - we'll still validate but not send all fields
  setState(() {
    fieldErrors = {
      'subject': subjectController.text.isEmpty,
      'dueDate': dueDateController.text.isEmpty,
      'assignedTo': selectedUserId == null,
    };
  });

  if (fieldErrors.values.contains(true)) {
    AppSnackBar.showError(context, 'Fill all the required field');
    return;
  }

  setState(() {
    _isSaving = true;
  });

  try {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final token = authProvider.token;

    if (token.isEmpty) {
      AppSnackBar.showError(context, 'Authentication required..please login');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Create a MINIMAL task update - ONLY subject, status and due_date
    // Completely exclude any reference to the assigned user for now
    final taskData = {
      'id': widget.taskId,
      'subject': subjectController.text,
      'status': selectedStatus,
      'due_date': dueDateController.text,
      // Exclude assigned user completely for this test
    };
    
    // Only include related_to_object_id if it exists in the original task
    if (widget.taskDetails['related_to_object_id'] != null) {
      taskData['related_to_object_id'] = widget.taskDetails['related_to_object_id'];
    }
    
    print('🔄 Minimal Task Update Data:');
    print('🆔 Task ID: ${widget.taskId}');
    print('🔄 Full Data: $taskData');

    // Use dataProvider to update the task
    final result = await dataProvider.updateMinimalTask(widget.taskId, taskData, token);

    if (result['success']) {
      // If minimal update works, we can try adding the user assignment in a separate call
      final bool shouldUpdateUser = selectedUserId != null && 
          (widget.taskDetails['assigned_to_id'] != selectedUserId);
          
      if (shouldUpdateUser) {
        print('✅ Basic update successful! Now trying to update assigned user separately...');
        await _updateAssignedUserSeparately(widget.taskId, selectedUserId!, token, dataProvider);
      }
      
      AppSnackBar.showSuccess(context, 'Task updated successfully');
      Navigator.pop(context, true);
    } else {
      String errorMessage = result['error'] ?? 'Failed to update task';
      AppSnackBar.showError(context, errorMessage);
    }
  } catch (e) {
    print('❌ Error in _saveTask: $e');
    AppSnackBar.showError(context, 'Error updating task: $e');
  } finally {
    setState(() {
      _isSaving = false;
    });
  }
}

// New method to update just the assigned user in a separate API call
Future<void> _updateAssignedUserSeparately(
  String taskId, 
  String userId, 
  String token,
  DataProvider dataProvider
) async {
  try {
    // Try different field names that the API might accept
    final possibleFieldNames = [
      'user_id',
      'assigned_user_id',
      'assignee_id',
      'owner_id'
    ];
    
    bool updated = false;
    String lastError = '';
    
    // Try each field name until one works
    for (final fieldName in possibleFieldNames) {
      if (updated) break;
      
      print('🧪 Attempting to update user with field: $fieldName = $userId');
      
      final userData = {
        'id': taskId,
        fieldName: userId,
      };
      
      final result = await dataProvider.updateMinimalTask(taskId, userData, token);
      
      if (result['success']) {
        print('✅ Successfully updated user with field: $fieldName');
        updated = true;
      } else {
        lastError = result['error'] ?? 'Unknown error';
        print('❌ Failed with field $fieldName: $lastError');
      }
    }
    
    if (!updated) {
      print('⚠️ Could not update assigned user after trying all field names');
      print('⚠️ Last error: $lastError');
    }
  } catch (e) {
    print('❌ Error in _updateAssignedUserSeparately: $e');
  }
}
  Widget buildFormField({
    required String label,
    required bool isRequired,
    required Widget child,
    bool isError = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isError ? AppColors.error : AppColors.divider,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: AppDimensions.spacingS),
                  child: child,
                ),
                // Positioned label
                Positioned(
                  left: AppDimensions.spacingM,
                  top: -AppDimensions.spacingXs,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
                    color: Colors.white,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: AppDimensions.textS,
                            color: isError ? AppColors.error : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isRequired)
                          Text(
                            ' *',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingL),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.spacingL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Task Information',
                              style: AppTextStyles.cardTitle,
                            ),
                            SizedBox(height: AppDimensions.spacingXl),
                            Expanded(
                              child: ListView(
                                children: [
                                  // Subject field
                                  buildFormField(
                                    label: 'Subject',
                                    isRequired: true,
                                    isError: fieldErrors['subject'] ?? false,
                                    child: TextFormField(
                                      controller: subjectController,
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: AppDimensions.spacingL,
                                          vertical: AppDimensions.spacingM,
                                        ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  
                                  // Due Date field
                                  buildFormField(
                                    label: 'Due Date',
                                    isRequired: true,
                                    isError: fieldErrors['dueDate'] ?? false,
                                    child: TextFormField(
                                      controller: dueDateController,
                                      readOnly: true,
                                      onTap: () => _selectDate(context),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: AppDimensions.spacingL,
                                          vertical: AppDimensions.spacingM,
                                        ),
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        suffixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                  
                                  // Assigned To dropdown field
                                  buildFormField(
                                    label: 'Assigned To',
                                    isRequired: true,
                                    isError: fieldErrors['assignedTo'] ?? false,
                                    child: _isLoadingUsers
                                      ? Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: AppDimensions.spacingL,
                                            vertical: AppDimensions.spacingM,
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              SizedBox(width: AppDimensions.spacingM),
                                              Text('Loading users...'),
                                            ],
                                          ),
                                        )
                                      : Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: AppDimensions.spacingL,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedUserId,
                                                  isExpanded: true,
                                                  hint: Text('Select User'),
                                                  style: AppTextStyles.bodyMedium,
                                                  items: _users.map((user) {
                                                    return DropdownMenuItem<String>(
                                                      value: user['id'].toString(),
                                                      child: Text(user['name'] != null && user['name'].isNotEmpty
                                                        ? user['name']
                                                        : (user['email'] ?? 'Unknown User')),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? newValue) {
                                                    if (newValue != null) {
                                                      setState(() {
                                                        selectedUserId = newValue;
                                                        // Find the user and update the name
                                                        final selectedUser = _users.firstWhere(
                                                          (user) => user['id'].toString() == newValue,
                                                          orElse: () => {},
                                                        );
                                                        if (selectedUser.isNotEmpty) {
                                                          selectedUserName = selectedUser['name'];
                                                        }
                                                        fieldErrors['assignedTo'] = false;
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                              if (selectedUserId != null)
                                                Padding(
                                                  padding: EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    'Selected: ${selectedUserName ?? 'Unknown User'}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                  ),
                                  
                                  // Status dropdown
                                  buildFormField(
                                    label: 'Status',
                                    isRequired: true,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: AppDimensions.spacingL,
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedStatus,
                                          isExpanded: true,
                                          style: AppTextStyles.bodyMedium,
                                          items: [
                                            'Not Started',
                                            'In Progress',
                                            'Completed',
                                            'On Hold',
                                            'Cancelled',
                                            'Planned',
                                            'Follow Up'
                                          ].map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              setState(() {
                                                selectedStatus = newValue;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Related To field
                                  buildFormField(
  label: 'Related To',
  isRequired: false,
  child: TextFormField(
    controller: relatedToController,
    readOnly: widget.taskDetails['related_to_id'] != null, // Make read-only if it has a parent
    decoration: InputDecoration(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingM,
      ),
      border: InputBorder.none,
      focusedBorder: InputBorder.none,
      enabledBorder: InputBorder.none,
      errorBorder: InputBorder.none, 
      disabledBorder: InputBorder.none,
      // Add a tooltip icon if it's related to a parent
      suffixIcon: widget.taskDetails['related_to_id'] != null 
        ? Tooltip(
            message: 'This task is linked to a ${_getRelatedToType()} record',
            child: Icon(Icons.info_outline, color: AppColors.primary),
          )
        : null,
    ),
  ),
),
                                  
                                  // Description field (if available in original task)
                                  if (widget.taskDetails.containsKey('description'))
                                    buildFormField(
                                      label: 'Description',
                                      isRequired: false,
                                      child: TextFormField(
                                        controller: descriptionController,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: AppDimensions.spacingL,
                                            vertical: AppDimensions.spacingL,
                                          ),
                                          border: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: AppDimensions.spacingL),
                            SizedBox(
                              width: double.infinity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Cancel button
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: AppButtonStyles.dialogCancelButton,
                                    child: Text('Cancel'),
                                  ),
                                  SizedBox(width: AppDimensions.spacingL),
                                  // Save button
                                  TextButton(
                                    onPressed: _isSaving ? null : _saveTask,
                                    style: AppButtonStyles.dialogConfirmButton,
                                    child: _isSaving
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: AppColors.textWhite,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text('Save'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
  String _getRelatedToType() {
  // Check if we can determine the type from the related_to_id format
  // This is just an example - modify according to your actual ID format
  final relatedToId = widget.taskDetails['related_to_id']?.toString() ?? '';
  if (relatedToId.startsWith('le')) {
    return 'Lead';
  } else if (relatedToId.startsWith('co')) {
    return 'Contact';
  } else if (relatedToId.startsWith('ac')) {
    return 'Account';
  } else if (relatedToId.startsWith('op')) {
    return 'Opportunity';
  } else {
    return 'Parent';
  }
}
}