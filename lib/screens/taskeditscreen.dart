import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart'; // Make sure to import the data provider
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';

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

  Future<void> _saveTask() async {
    setState(() {
      fieldErrors = {
        'subject': subjectController.text.isEmpty,
        'dueDate': dueDateController.text.isEmpty,
        'assignedTo': assignedToController.text.isEmpty,
      };
    });

    if (fieldErrors.values.contains(true)) {
      showTopSnackBar(
        message: 'Please fill in all required fields',
        backgroundColor: AppColors.error,
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

      if (token.isEmpty) {
        showTopSnackBar(
          message: 'Authentication required. Please log in.',
          backgroundColor: AppColors.error,
        );
        return;
      }

      final taskData = {
        'subject': subjectController.text,
        'due_date': dueDateController.text,
        'assigned_to': assignedToController.text,
        'status': selectedStatus,
        'related_to': relatedToController.text,
      };
      
      if (widget.taskDetails.containsKey('description')) {
        taskData['description'] = descriptionController.text;
      }

      // Use dataProvider to update the task
      final result = await dataProvider.updateTask(widget.taskId, taskData, token);

      if (result['success']) {
        showTopSnackBar(
          message: 'Task updated successfully',
          backgroundColor: AppColors.success,
        );
        Navigator.pop(context, true);
      } else {
        String errorMessage = result['error'] ?? 'Failed to update task';
        showTopSnackBar(
          message: errorMessage,
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      showTopSnackBar(
        message: 'Error updating task: $e',
        backgroundColor: AppColors.error,
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
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
                                  
                                  // Assigned To field
                                  buildFormField(
                                    label: 'Assigned To',
                                    isRequired: true,
                                    isError: fieldErrors['assignedTo'] ?? false,
                                    child: TextFormField(
                                      controller: assignedToController,
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
}