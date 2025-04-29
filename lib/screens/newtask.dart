import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart'; // Import your data provider
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

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
  final TextEditingController assignedToController = TextEditingController();
  final TextEditingController relatedToController = TextEditingController();
  String selectedStatus = 'Not Started';
  DateTime? selectedDate;
  bool _isSaving = false;
  
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
  }

  // Show custom snackbar at the top
  void showTopSnackBar({required String message, required Color backgroundColor}) {
    // Clear any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // Show the new snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 3),
      ),
    );
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
                          
                          // Assigned To field
                          buildFormField(
                            label: 'Assigned To',
                            isRequired: true,
                            isError: fieldErrors['assignedTo'] ?? false,
                            child: TextField(
                              controller: assignedToController,
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
      'assignedTo': assignedToController.text.isEmpty,
    };
  });

  // Check if any field is empty
  if (fieldErrors.values.contains(true)) {
    showTopSnackBar(
      message: 'Please fill in all required fields',
      backgroundColor: Theme.of(context).colorScheme.error,
    );
    return;
  }

  // Check if assignedTo field has content
  if (assignedToController.text.trim().isEmpty) {
    setState(() {
      fieldErrors['assignedTo'] = true;
    });
    showTopSnackBar(
      message: 'Please specify a user to assign the task to',
      backgroundColor: Theme.of(context).colorScheme.error,
    );
    return;
  }

  setState(() {
    _isSaving = true;
  });

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final dataProvider = Provider.of<DataProvider>(context, listen: false);
  final token = authProvider.token;
  
  // Try to get user ID from data provider based on assigned user's name
  Map<String, dynamic>? userInfo;
  try {
    userInfo = await dataProvider.getUserByName(assignedToController.text, token);
  } catch (e) {
    print('❌ Error in getUserByName: $e');
  }
  
  // Check if we found a valid user ID
  if (userInfo == null || !userInfo.containsKey('id')) {
    setState(() {
      _isSaving = false;
      fieldErrors['assignedTo'] = true;
    });
    showTopSnackBar(
      message: 'Could not find a user with the name "${assignedToController.text}"',
      backgroundColor: Colors.red,
    );
    return;
  }
  
  final userId = userInfo['id'];
  print('✅ Found user ID: $userId for ${assignedToController.text}');

  final taskData = {
    'subject': subjectController.text,
    'status': selectedStatus,
    'due_date': dueDateController.text,
    'assigned_to_id': userId, // The specific user ID we found
    'assigned_to': assignedToController.text, // Also include the display name
    'related_object_id': widget.relatedObjectId,
    'related_to': widget.relatedObjectName ?? widget.relatedObjectType,
  };

  print('📦 Final task data: $taskData');

  try {
    // Using the data provider's createTask method
    final result = await dataProvider.createTask(
      taskData, 
      token, 
      widget.relatedObjectType
    );

    if (result['success']) {
      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else {
      showTopSnackBar(
        message: result['message'] ?? 'Failed to add task',
        backgroundColor: Colors.red,
      );
    }
  } catch (e) {
    print('❌ Error creating task: $e');
    showTopSnackBar(
      message: 'Error creating task: $e',
      backgroundColor: Colors.red,
    );
  } finally {
    setState(() {
      _isSaving = false;
    });
  }
}
}