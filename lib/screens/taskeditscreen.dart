import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

class TaskEditScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskDetails;

  const TaskEditScreen({
    Key? key,
    required this.taskId,
    required this.taskDetails,
  }) : super(key: key);

  @override
  _TaskEditScreenState createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  
  // Controllers for editing fields
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();
  final TextEditingController assignedToController = TextEditingController();
  final TextEditingController relatedToController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  
  String selectedStatus = 'Not Started';
  DateTime? selectedDate;
  
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
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    subjectController.dispose();
    dueDateController.dispose();
    assignedToController.dispose();
    relatedToController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
  
  void _initializeControllers() {
    // Initialize text controllers with values from taskDetails
    subjectController.text = widget.taskDetails['subject'] ?? '';
    dueDateController.text = widget.taskDetails['due_date'] ?? '';
    assignedToController.text = widget.taskDetails['assigned_to'] ?? '';
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

  // Function to show date picker with custom theme matching card color
  Future<void> _selectDate(BuildContext context) async {
    final colorScheme = ColorScheme.light(
      primary: Colors.blue[700]!,
      onPrimary: Colors.white,
      onSurface: Colors.black,
      surface: Colors.white, // Match card color
    );
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2025, 12, 31),
      // Custom theme for the date picker
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme,
            dialogBackgroundColor: Colors.white, // Card color
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
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

  Future<void> _saveTask() async {
    // Reset all error flags
    setState(() {
      fieldErrors = {
        'subject': subjectController.text.isEmpty,
        'dueDate': dueDateController.text.isEmpty,
        'assignedTo': assignedToController.text.isEmpty,
      };
    });

    // Check if any required field is empty
    if (fieldErrors.values.contains(true)) {
      showTopSnackBar(
        message: 'Please fill in all required fields',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      // Check if token exists
      if (token.isEmpty) {
        showTopSnackBar(
          message: 'Authentication required. Please log in.',
          backgroundColor: Colors.red,
        );
        return;
      }

      // Prepare data to update
      final taskData = {
        'subject': subjectController.text,
        'due_date': dueDateController.text,
        'assigned_to': assignedToController.text,
        'status': selectedStatus,
        'related_to': relatedToController.text,
      };
      
      // Add description if it exists in the original task
      if (widget.taskDetails.containsKey('description')) {
        taskData['description'] = descriptionController.text;
      }

      // Update task API endpoint
      final url = 'https://qa.api.bussus.com/v2/api/task';
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'id': widget.taskId,
          'data': taskData
        }),
      );

      print('📤 Update task response: ${response.statusCode}');
      print('📤 Update task response body: ${response.body}');

      if (response.statusCode == 200) {
        showTopSnackBar(
          message: 'Task updated successfully',
          backgroundColor: Colors.green,
        );
        
        // Return true to indicate successful update
        Navigator.pop(context, true);
      } else {
        String errorMessage;
        try {
          final responseData = json.decode(response.body);
          errorMessage = responseData['message'] ?? 'Failed to update task';
        } catch (e) {
          errorMessage = 'Failed to update task. Status code: ${response.statusCode}';
        }

        showTopSnackBar(
          message: errorMessage,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      print('❌ Error updating task: $e');
      showTopSnackBar(
        message: 'Error updating task: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Creates a form field with properly aligned floating label
  Widget buildFormField({
    required String label,
    required bool isRequired,
    required Widget child,
    bool isError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The input field or dropdown
              child,
              // Label positioned on the border with improved visibility
              Positioned(
                left: 10,
                top: -9,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    // Add shadow for better visibility
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white,
                        spreadRadius: 3,
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isError ? Colors.red : Colors.black87,
                          // Make label bolder for better visibility
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isRequired)
                        Text(
                          ' *',
                          style: TextStyle(
                            color: Colors.red,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Task',
          style: const TextStyle(color: Colors.white, fontSize: 18)
        ),
        backgroundColor: Colors.blue[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.blue.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: EdgeInsets.all(16),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    color: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Task Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
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
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
                                        ),
                                        labelText: '',
                                        floatingLabelBehavior: FloatingLabelBehavior.never,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        errorText: (fieldErrors['subject'] ?? false) ? 'This field is required' : null,
                                        errorStyle: TextStyle(
                                          color: Colors.transparent, // Hide the error text as we're handling it differently
                                          fontSize: 0,
                                        ),
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
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
                                        ),
                                        suffixIcon: Icon(Icons.calendar_today),
                                        labelText: '',
                                        floatingLabelBehavior: FloatingLabelBehavior.never,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        errorText: (fieldErrors['dueDate'] ?? false) ? 'This field is required' : null,
                                        errorStyle: TextStyle(
                                          color: Colors.transparent, // Hide the error text as we're handling it differently
                                          fontSize: 0,
                                        ),
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
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
                                        ),
                                        labelText: '',
                                        floatingLabelBehavior: FloatingLabelBehavior.never,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        errorText: (fieldErrors['assignedTo'] ?? false) ? 'This field is required' : null,
                                        errorStyle: TextStyle(
                                          color: Colors.transparent, // Hide the error text as we're handling it differently
                                          fontSize: 0,
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
                                        child: DropdownButton<String>(
                                          value: selectedStatus,
                                          isExpanded: true,
                                          dropdownColor: Colors.white,
                                          icon: Icon(Icons.arrow_drop_down, color: Colors.black87),
                                          style: TextStyle(color: Colors.black87, fontSize: 16),
                                          padding: EdgeInsets.symmetric(horizontal: 16),
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
                                    child: TextField(
                                      controller: relatedToController,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
                                        ),
                                        labelText: '',
                                        floatingLabelBehavior: FloatingLabelBehavior.never,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                    ),
                                  ),
                                  
                                  // Description field (if available in original task)
                                  if (widget.taskDetails.containsKey('description'))
                                    buildFormField(
                                      label: 'Description',
                                      isRequired: false,
                                      child: TextField(
                                        controller: descriptionController,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
                                          ),
                                          labelText: '',
                                          floatingLabelBehavior: FloatingLabelBehavior.never,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Cancel button - white with black text
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  minimumSize: Size(120, 45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22), // Makes it oval
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: Text('Cancel'),
                              ),
                              SizedBox(width: 16),
                              // Save button - blue with white text
                              ElevatedButton(
                                onPressed: _isSaving ? null : _saveTask,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(120, 45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22), // Makes it oval
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
    );
  }
}