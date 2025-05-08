import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_snackbar.dart'; // Import our SnackBar utility

class TaskFormScreen extends StatefulWidget {
  final String relatedObjectId;
  final String relatedObjectType;
  final String? relatedObjectName;

  const TaskFormScreen({
    super.key,
    required this.relatedObjectId,
    required this.relatedObjectType,
    this.relatedObjectName,
  });

  @override
  _TaskFormScreenState createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();
  final TextEditingController relatedToController = TextEditingController();
  String selectedStatus = 'Not Started';
  DateTime? selectedDate;
  bool _isSaving = false;
  bool _isLoadingUsers = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String? selectedUserId; // To store selected user ID
  
  // Error state variables
  Map<String, bool> fieldErrors = {
    'subject': false,
    'dueDate': false,
    'assignedTo': false,
  };

  @override
  void initState() {
    super.initState();
    // Initialize related to field
    relatedToController.text = widget.relatedObjectName ?? widget.relatedObjectType;
    // Fetch users when screen loads
    _fetchUsers();
  }

  // Fetch users for the dropdown
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
        });
        print('✅ Fetched ${_users.length} users');
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

  // Function to show date picker with theme styling
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2025, 12, 31),
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dueDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        fieldErrors['dueDate'] = false;
      });
    }
  }

  // Fixed form field builder
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              // The input field or dropdown with appropriate constraints
              SizedBox(
                width: double.infinity,
                child: child,
              ),
              // Label positioned on the border
              Positioned(
                left: 10,
                top: -9,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
                  color: Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isError ? Theme.of(context).colorScheme.error : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isRequired)
                        Text(
                          ' *',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("New Task"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacingL),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: AppDimensions.spacingL),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Subject field
                          buildFormField(
                            label: 'Subject',
                            isRequired: true,
                            isError: fieldErrors['subject'] ?? false,
                            child: TextField(
                              controller: subjectController,
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 14
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                errorStyle: TextStyle(height: 0),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  setState(() {
                                    fieldErrors['subject'] = false;
                                  });
                                }
                              },
                            ),
                          ),
                          
                          // Due Date field
                          buildFormField(
                            label: 'Due Date',
                            isRequired: true,
                            isError: fieldErrors['dueDate'] ?? false,
                            child: TextField(
                              controller: dueDateController,
                              readOnly: true,
                              onTap: () => _selectDate(context),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 14
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                suffixIcon: Icon(Icons.calendar_today),
                                errorStyle: TextStyle(height: 0),
                              ),
                            ),
                          ),
                          
                          // Assigned To dropdown field
                          buildFormField(
                            label: 'Assigned To',
                            isRequired: true,
                            isError: fieldErrors['assignedTo'] ?? false,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isLoadingUsers
                                ? Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Loading users...'),
                                        ],
                                      ),
                                    ),
                                  )
                                : DropdownButtonHideUnderline(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: DropdownButton<String>(
                                        value: selectedUserId,
                                        isExpanded: true,
                                        hint: Text('Select User'),
                                        icon: Icon(Icons.arrow_drop_down),
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
                                              fieldErrors['assignedTo'] = false;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                          
                          // Status dropdown
                          buildFormField(
                            label: 'Status',
                            isRequired: true,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                                  child: DropdownButton<String>(
                                    value: selectedStatus,
                                    isExpanded: true,
                                    icon: Icon(Icons.arrow_drop_down),
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
                          ),
                          
                          // Related To field
                          buildFormField(
                            label: 'Related To',
                            isRequired: true,
                            child: TextField(
                              controller: relatedToController,
                              readOnly: true,
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 14
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Cancel button
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(120, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text('Cancel'),
                      ),
                      SizedBox(width: AppDimensions.spacingL),
                      // Save button
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveTask,
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(120, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTask() async {
    // Reset all error flags
    setState(() {
      fieldErrors = {
        'subject': subjectController.text.isEmpty,
        'dueDate': dueDateController.text.isEmpty,
        'assignedTo': selectedUserId == null,
      };
    });

    // Check if any field is empty
    if (fieldErrors.values.contains(true)) {
      // Using our global SnackBar utility
      AppSnackBar.showError(
        context,
        'Please fill in all required fields',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final token = authProvider.token;
    
    // Find the selected user to get their data
    final selectedUser = _users.firstWhere(
      (user) => user['id'].toString() == selectedUserId,
      orElse: () => {},
    );
    
    if (selectedUser.isEmpty) {
      setState(() {
        _isSaving = false;
        fieldErrors['assignedTo'] = true;
      });
      
      // Using our global SnackBar utility
      AppSnackBar.showError(
        context,
        'Please select a valid user to assign the task to',
      );
      return;
    }
    
    final String userEmail = selectedUser['email'] ?? '';
    final String userName = selectedUser['name'] ?? userEmail;
    
    print('✅ Found user: $userName (ID: $selectedUserId)');

    // Prepare task data using the expected format based on successful example
    final taskData = {
      'subject': subjectController.text,
      'status': selectedStatus,
      'due_date': dueDateController.text,
      'assigned_to_id': selectedUserId, // Will be converted to user_id in provider
      'assigned_to': userName, // Using full name instead of email
      'assigned_to_name': userName, // Include for backward compatibility
      'related_object_id': widget.relatedObjectId,
      'related_to': widget.relatedObjectName ?? widget.relatedObjectType,
    };

    print('📦 Final task data: $taskData');

    try {
      // Using the data provider's createTask method
      final result = await dataProvider.createTask(
        taskData, 
        token, 
      );

      if (result['success']) {
        // Using our global SnackBar utility for success message
        AppSnackBar.showSuccess(
          context,
          'Task added successfully',
        );
        Navigator.pop(context, true);
      } else {
        // Using our global SnackBar utility for error message
        AppSnackBar.showError(
          context,
          result['error'] ?? 'Failed to add task',
        );
      }
    } catch (e) {
      print('❌ Error creating task: $e');
      
      // Using our global SnackBar utility for error message
      AppSnackBar.showError(
        context,
        'Error creating task: $e',
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
}