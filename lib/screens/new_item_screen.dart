import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NewItemScreen extends StatefulWidget {
  final String type;

  NewItemScreen({required this.type});

  @override
  _NewItemScreenState createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  Map<String, TextEditingController> _controllers = {};
  List<ColumnInfo> _requiredFields = [];
  List<ColumnInfo> _optionalFields = [];

  // Using a simple Map<String, String> for dropdown values
  Map<String, String> _dropdownValues = {};

  Map<String, Map<String, String>> _dropdownMappings = {
    'customer_type': {
      'Engineer': 'EN',
      'Consumer': 'CO',
      'Contractor': 'CN',
      'Architect': 'AR',
      'Influencer': 'IN'
    }
  };

  // Cache for parsed dropdown options to avoid repeated parsing
  Map<String, List<String>> _dropdownOptionsCache = {};

  @override
  void initState() {
    super.initState();
    _setupFields();
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _setupFields() {
    Future.delayed(Duration.zero, () {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final allColumns = dataProvider.allColumns;

      // Find the phone column and make it required
      for (int i = 0; i < allColumns.length; i++) {
        if (allColumns[i].name == 'phone') {
          // Create a new column info with required set to true
          allColumns[i] = ColumnInfo(
            name: allColumns[i].name,
            label: allColumns[i].label,
            datatype: allColumns[i].datatype,
            required: true, // Set phone to required
            values: allColumns[i].values,
          );
          break;
        }
      }

      // Split fields into required and optional
      _requiredFields = allColumns.where((col) => col.required).toList();
      _optionalFields = allColumns.where((col) => !col.required).toList();

      // Create text controllers for all fields
      for (var column in allColumns) {
        _controllers[column.name] = TextEditingController();

        // Set default values for date fields
        if ((column.name == 'created_date' || column.datatype.toLowerCase() == 'date') && column.name != 'last_modified_date') {
          // Set current date for created_date and other date fields (except last_modified)
          final now = DateTime.now();
          final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          _controllers[column.name]!.text = formattedDate;
        }
      }

      // Pre-process all dropdown options
      for (var column in allColumns) {
        if (_hasDropdownValues(column)) {
          // Parse dropdown options once and cache them
          List<String> options = _parseDropdownValues(column);
          _dropdownOptionsCache[column.name] = options;

          // Initialize dropdown value based on whether it's required
          if (column.required && options.isNotEmpty) {
            // Find first non-placeholder option for required fields
            String? validOption;
            for (String opt in options) {
              if (!opt.startsWith('--')) {
                validOption = opt;
                break;
              }
            }

            _dropdownValues[column.name] = validOption ?? options.first;
          } else {
            // For optional fields, initialize with a blank value
            _dropdownValues[column.name] = '';
          }
        }
      }

      if (mounted) setState(() {});
    });
  }

  bool _hasDropdownValues(ColumnInfo column) {
    return column.values.isNotEmpty;
  }

  List<String> _parseDropdownValues(ColumnInfo column) {
    if (_dropdownOptionsCache.containsKey(column.name)) {
      return _dropdownOptionsCache[column.name]!;
    }

    List<String> result = [];
    if (column.values.isNotEmpty) {
      try {
        if (column.values.startsWith('[')) {
          // Try parsing as JSON array
          result = List<String>.from(json.decode(column.values));
        } else {
          // Try parsing as comma-separated or newline-separated list
          if (column.values.contains(',')) {
            result = column.values.split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (column.values.contains('\n')) {
            result = column.values.split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else {
            result = [column.values.trim()];
          }
        }
      } catch (e) {
        print('Error parsing dropdown values for ${column.name}: $e');
        return [];
      }
    }

    return result;
  }

  Future<void> _submitForm() async {
    // Debug print current values
    print('FORM VALUES BEFORE VALIDATION:');
    _controllers.forEach((key, controller) {
      print('Text field $key: "${controller.text}"');
    });
    _dropdownValues.forEach((key, value) {
      print('Dropdown field $key: "$value"');
    });

    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.red),
      );
      return;
    }

    print('Form validation passed');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);

      // Build the data to submit
      Map<String, dynamic> formData = {};

      // Add text field values
      _controllers.forEach((key, controller) {
        // Special handling for date fields
        if ((key == "created_date" || key == "last_modified_date" ||
            _requiredFields.any((col) => col.name == key && col.datatype.toLowerCase() == 'date') ||
            _optionalFields.any((col) => col.name == key && col.datatype.toLowerCase() == 'date'))) {

          // Only include non-empty date values
          if (controller.text.isNotEmpty) {
            // You might need to convert the date format based on your API requirements
            // Example: convert YYYY-MM-DD to MM/DD/YYYY or to ISO format
            formData[key] = controller.text; // Use as is, or convert if needed
          }
        }
        // Special handling for phone field
        if (key == "phone") {
          // Only include non-empty phone values
          if (controller.text.isNotEmpty) {
            formData[key] = controller.text;
          }
          // Don't include empty phone values at all
        }
        // Handle other fields as before
        else {
          bool isRequired = _requiredFields.any((col) => col.name == key);
          if (isRequired) {
            formData[key] = controller.text;
          } else if (controller.text.isNotEmpty) {
            formData[key] = controller.text;
          }
        }
      });

      // Handle dropdown values
      for (var column in [..._requiredFields, ..._optionalFields]) {
        if (_hasDropdownValues(column)) {
          String value = _dropdownValues[column.name] ?? '';

          // Only include non-empty values that aren't placeholders
          if (value.isNotEmpty && !value.startsWith('--')) {
            // Check if we need to map this value to a code
            if (_dropdownMappings.containsKey(column.name) &&
                _dropdownMappings[column.name]!.containsKey(value)) {
              formData[column.name] = _dropdownMappings[column.name]![value];
              print('Adding mapped dropdown value for ${column.name}: ${_dropdownMappings[column.name]![value]} (from $value)');
            } else {
              formData[column.name] = value;
              print('Adding dropdown value for ${column.name}: $value');
            }
          }
        }
      }

      // Use the dataProvider's createItem method instead of direct HTTP call
      print('SUBMITTING FORM DATA: $formData');

      final result = await dataProvider.createItem(widget.type, formData, authProvider.token);

      if (result['success']) {
        // Show success message and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New ${widget.type} created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              top: 100,
              left: 10,
              right: 10,
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        // Handle error
        setState(() {
          _error = result['message'] ?? 'Failed to create item.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error occurred: $e';
      });
      print('❌ Error creating new item: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // UI Helper Methods
  InputDecoration _inputDecoration(String fieldLabel, bool isRequired) {
    return InputDecoration(
      labelText: "$fieldLabel${isRequired ? ' *' : ''}",
      labelStyle: TextStyle(color: Colors.black),
      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black45),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black45),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue, width: 2),
      ),
      hintText: fieldLabel.toLowerCase() == 'phone' ? 'Must be unique' : null,
    );
  }

  Widget _buildForm() {
    // Group fields by section
    List<Map<String, dynamic>> sections = [
      {
        "title": "Required Information",
        "fields": _requiredFields,
      },
      {
        "title": "Optional Information",
        "fields": _optionalFields,
      }
    ];

    return Form(
      key: _formKey,
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Horizontal Line
              Center(
                child: Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: EdgeInsets.only(bottom: 16),
                ),
              ),
              // Form Fields grouped by sections
              ...sections.where((section) => (section["fields"] as List).isNotEmpty).expand((section) => [
                // Section Title & Line Below It
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section["title"],
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                      ),
                      SizedBox(height: 4),
                      Divider(color: Colors.grey[400]),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
                ...section["fields"].map<Widget>((field) => _buildField(field, field.required)).toList(),
              ]),

              // Error message
              if (_error != null) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.red.shade50,
                  child: Text(_error!, style: TextStyle(color: Colors.red)),
                ),
              ],

              // Submit button
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text(
                    'Create ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(ColumnInfo column, bool isRequired) {
    // Check if this is a date field
    if (column.datatype.toLowerCase() == 'date' ||
        column.name == 'created_date' ||
        column.name == 'last_modified_date') {
      return _buildDateField(column, isRequired);
    }
    // If this is a dropdown field
    if (_hasDropdownValues(column)) {
      // Get the dropdown options from cache
      List<String> options = _dropdownOptionsCache[column.name] ?? [];

      // Only build a dropdown if we actually have options
      if (options.isNotEmpty) {
        return _buildDropdownField(column, options, isRequired);
      }
    }

    // Default to text field for non-dropdown fields or empty dropdowns
    return _buildTextField(column, isRequired);
  }
  Widget _buildDateField(ColumnInfo column, bool isRequired) {
    final controller = _controllers[column.name] ?? TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(column.label, isRequired).copyWith(
          suffixIcon: Icon(Icons.calendar_today),
        ),
        readOnly: true, // Prevents keyboard from appearing
        onTap: () async {
          // Show date picker
          final DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );

          if (pickedDate != null) {
            // Format the date as you need
            final String formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";

            setState(() {
              controller.text = formattedDate;
            });
          }
        },
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'Please select ${column.label}';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildDropdownField(ColumnInfo column, List<String> options, bool isRequired) {
    // Initialize with a valid value from the options
    if (!_dropdownValues.containsKey(column.name)) {
      if (isRequired && options.isNotEmpty) {
        // Find first non-placeholder option
        for (String option in options) {
          if (!option.startsWith('--')) {
            _dropdownValues[column.name] = option;
            break;
          }
        }
      } else {
        _dropdownValues[column.name] = '';
      }
    }

    // Current value
    String? currentValue = _dropdownValues[column.name];

    // Clean up the options - remove whitespace and newlines
    List<String> cleanedOptions = options.map((option) => option.trim()).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: currentValue?.isEmpty == true ? null : currentValue,
        hint: Text('Select ${column.label}'),
        isExpanded: true,
        decoration: _inputDecoration(column.label, isRequired),
        onChanged: (String? newValue) {
          print('Dropdown ${column.name} changed to: "$newValue"');
          setState(() {
            _dropdownValues[column.name] = newValue ?? '';
          });
        },
        items: [
          // Add placeholder for optional fields
          if (!isRequired)
            DropdownMenuItem<String>(
              value: '',
              child: Text('None'),
            ),

          // Add cleaned options
          ...cleanedOptions.where((option) => option.isNotEmpty).map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTextField(ColumnInfo column, bool isRequired) {
    final controller = _controllers[column.name] ?? TextEditingController();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: _inputDecoration(column.label, isRequired),
        keyboardType: _getKeyboardType(column.datatype),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter ${column.label}';
          }
          if (column.name == 'phone' && value!.isEmpty) {
            return 'Phone must be unique. Please enter a value or leave this form.';
          }
          return null;
        } : null,
      ),
    );
  }

  TextInputType _getKeyboardType(String dataType) {
    switch (dataType.toLowerCase()) {
      case 'number':
      case 'integer':
      case 'decimal':
        return TextInputType.number;
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'url':
        return TextInputType.url;
      case 'date':
        return TextInputType.datetime;
      default:
        return TextInputType.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: Text(
          'New ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.blue.shade50,
      body: _controllers.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: _buildForm(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Label"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Leads"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Invoices"),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
        currentIndex: 1,
        selectedItemColor: Colors.blue,
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}