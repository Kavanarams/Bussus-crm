import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_snackbar.dart';
import '../theme/app_button_styles.dart';

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
  String? selectedStatus;
  DateTime? selectedDate;
  bool _isSaving = false;
  bool _isLoadingUsers = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String? selectedUserId;
  String? type;
  
  // Focus nodes for text fields
  final FocusNode subjectFocusNode = FocusNode();
  final FocusNode dueDateFocusNode = FocusNode();
  final FocusNode relatedToFocusNode = FocusNode();
  
  // Error state variables
  Map<String, bool> fieldErrors = {
    'subject': false,
    'dueDate': false,
    'assignedTo': false,
  };

  @override
  void initState() {
    super.initState();
    // Initialize related to field with proper spacing
    relatedToController.text = widget.relatedObjectName ?? widget.relatedObjectType;
    // Fetch users when screen loads - use post frame callback to avoid build issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUsers();
    });
  }

  @override
  void dispose() {
    subjectController.dispose();
    dueDateController.dispose();
    relatedToController.dispose();
    subjectFocusNode.dispose();
    dueDateFocusNode.dispose();
    relatedToFocusNode.dispose();
    super.dispose();
  }

  // Simplified user fetching for the direct array API response
  Future<void> _fetchUsers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingUsers = true;
      _error = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingUsers = false;
            _error = 'Authentication required to fetch users. Please log in.';
          });
        }
        return;
      }
      
      print('🌐 Fetching users...');
      final result = await dataProvider.getUsers(token);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        final dynamic userData = result['data'];
        
        if (userData is List) {
          // The API returns a direct array of users like:
          // [{"id": "GEN_768311c14", "name": "Kavya"}, ...]
          List<Map<String, dynamic>> processedUsers = [];
          
          for (var user in userData) {
            if (user is Map<String, dynamic>) {
              final userId = user['id']?.toString();
              final userName = user['name']?.toString() ?? '';
              
              if (userId != null && userId.isNotEmpty) {
                processedUsers.add({
                  'id': userId,
                  'name': userName,
                  'email': user['email']?.toString() ?? '',
                  'first_name': user['first_name']?.toString() ?? '',
                  'last_name': user['last_name']?.toString() ?? '',
                });
              }
            }
          }
          
          setState(() {
            _users = processedUsers;
            _isLoadingUsers = false;
          });
          
          print('✅ Successfully loaded ${_users.length} users');
          
          // Debug: Print first few users
          if (_users.isNotEmpty) {
            print('👤 Sample users:');
            for (int i = 0; i < (_users.length > 3 ? 3 : _users.length); i++) {
              print('  - ${_users[i]['name']} (${_users[i]['id']})');
            }
          }
          
        } else {
          print('❌ Expected List but got ${userData.runtimeType}: $userData');
          setState(() {
            _isLoadingUsers = false;
            _error = 'Unexpected data format from server';
          });
        }
        
      } else {
        setState(() {
          _isLoadingUsers = false;
          _error = 'Failed to load users: ${result['error'] ?? 'Unknown error'}';
        });
        print('❌ Failed to fetch users: ${result['error']}');
      }
    } catch (e, stackTrace) {
      print('❌ Exception in _fetchUsers: $e');
      print('📍 Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
          _error = 'Error loading users: $e';
        });
      }
    }
  }

  // Safe getter for user ID - handles both string and int IDs
  String? _safeGetId(dynamic id) {
    if (id == null) return null;
    if (id is String && id.isNotEmpty) return id;
    if (id is int) return id.toString();
    if (id is double) return id.toInt().toString();
    return null;
  }

  // Safe getter for string values
  String _safeGetString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
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

  // Fixed form field builder with proper label positioning
  Widget buildFormField({
    required String label,
    required bool isRequired,
    required Widget child,
    bool isError = false,
    FocusNode? focusNode,
    bool isGreyTheme = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // The input field or dropdown
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 8),
                child: child,
              ),
              // Label positioned properly above the border
              Positioned(
                left: 12,
                top: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isError 
                            ? Theme.of(context).colorScheme.error 
                            : Colors.black87,
                          fontWeight: FontWeight.w500,
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

  // Enhanced user display name function - simplified for the API response
  String _getUserDisplayName(Map<String, dynamic> user) {
    final name = user['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    
    final firstName = user['first_name']?.toString().trim() ?? '';
    final lastName = user['last_name']?.toString().trim() ?? '';
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }
    
    final email = user['email']?.toString().trim() ?? '';
    return email.isNotEmpty ? email : 'Unknown User';
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingL),
                  
                  // Show error message if users failed to load
                  if (_error != null)
                    Container(
                      margin: EdgeInsets.only(bottom: AppDimensions.spacingM),
                      padding: EdgeInsets.all(AppDimensions.spacingM),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.red.shade600),
                            onPressed: _fetchUsers,
                            tooltip: 'Retry',
                          ),
                        ],
                      ),
                    ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Subject field
                          buildFormField(
                            label: 'Subject',
                            isRequired: true,
                            isError: fieldErrors['subject'] ?? false,
                            focusNode: subjectFocusNode,
                            child: TextField(
                              controller: subjectController,
                              focusNode: subjectFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Enter subject',
                                hintStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 16
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.error,
                                    width: 1,
                                  ),
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
                            focusNode: dueDateFocusNode,
                            child: TextField(
                              controller: dueDateController,
                              focusNode: dueDateFocusNode,
                              readOnly: true,
                              onTap: () => _selectDate(context),
                              decoration: InputDecoration(
                                hintText: 'Select due date',
                                hintStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 16
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  ),
                                ),
                                suffixIcon: Icon(Icons.calendar_today),
                                errorStyle: TextStyle(height: 0),
                              ),
                            ),
                          ),
                          
                          // Assigned To dropdown field with enhanced error handling
                          buildFormField(
                            label: 'Assigned To',
                            isRequired: true,
                            isError: fieldErrors['assignedTo'] ?? false,
                            child: Container(
                              height: 56,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: fieldErrors['assignedTo'] == true 
                                    ? Theme.of(context).colorScheme.error
                                    : Colors.grey.shade400
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: _isLoadingUsers
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Loading users...'),
                                    ],
                                  )
                                : _error != null
                                  ? Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(child: Text('Failed to load users', style: TextStyle(color: Colors.red))),
                                      ],
                                    )
                                  : DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedUserId,
                                        isExpanded: true,
                                        hint: Text(
                                          'Select User',
                                          style: TextStyle(color: Colors.grey[500]),
                                        ),
                                        icon: Icon(Icons.arrow_drop_down),
                                        dropdownColor: Colors.white,
                                        items: _users.map((user) {
                                          final userId = user['id']?.toString();
                                          if (userId == null || userId.isEmpty) return null;
                                          
                                          return DropdownMenuItem<String>(
                                            value: userId,
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(vertical: 4),
                                              child: Text(
                                                _getUserDisplayName(user),
                                                style: TextStyle(fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }).where((item) => item != null).cast<DropdownMenuItem<String>>().toList(),
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
                          
                          // Status dropdown
                          buildFormField(
                            label: 'Status',
                            isRequired: true,
                            child: Container(
                              height: 56,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  isExpanded: true,
                                  hint: Text(
                                    'Select status',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 16,
                                    ),
                                  ),
                                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                                  dropdownColor: Colors.white,
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
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          value,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
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
                            isRequired: true,
                            focusNode: relatedToFocusNode,
                            child: TextField(
                              controller: relatedToController,
                              focusNode: relatedToFocusNode,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: 'Related object',
                                hintStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, 
                                  vertical: 16
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingL),
                  // Updated buttons using AppButtonStyles
                  Row(
                    children: [
                      // Cancel button using secondary style
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: AppButtonStyles.secondaryButton,
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: AppDimensions.spacingM),
                      // Save button using primary style
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveTask,
                          style: AppButtonStyles.primaryButton,
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
      AppSnackBar.showError(
        context,
        'Please fill in all required fields',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final token = authProvider.token;
      
      // Find the selected user to get their data with simplified lookup
      Map<String, dynamic>? selectedUser;
      try {
        selectedUser = _users.firstWhere(
          (user) => user['id']?.toString() == selectedUserId,
        );
      } catch (e) {
        print('❌ User not found for ID: $selectedUserId');
        selectedUser = null;
      }
      
      if (selectedUser == null) {
        setState(() {
          _isSaving = false;
          fieldErrors['assignedTo'] = true;
        });
        
        AppSnackBar.showError(
          context,
          'Please select a valid user to assign the task to',
        );
        return;
      }
      
      final String userEmail = selectedUser['email']?.toString() ?? '';
      final String userName = _getUserDisplayName(selectedUser);
      
      print('✅ Found user: $userName (ID: $selectedUserId, Email: $userEmail)');

      // Prepare task data
      final taskData = {
        'subject': subjectController.text.trim(),
        'status': selectedStatus ?? 'Not Started',
        'due_date': dueDateController.text,
        'assigned_to_id': selectedUserId,
        'assigned_to': userName,
        'assigned_to_name': userName,
        'related_object_id': widget.relatedObjectId,
        'related_to': widget.relatedObjectName ?? widget.relatedObjectType,
      };

      print('📦 Final task data: $taskData');

      final result = await dataProvider.createTask(taskData, token);

      if (!mounted) return;

      if (result['success'] == true) {
        AppSnackBar.showSuccess(
          context,
          'Task added successfully',
        );
        Navigator.pop(context, true);
      } else {
        AppSnackBar.showError(
          context,
          result['error'] ?? 'Failed to add task',
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error creating task: $e');
      print('📍 Stack trace: $stackTrace');
      
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Error creating task: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}