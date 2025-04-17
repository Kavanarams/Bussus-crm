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
  List<ColumnInfo> _allFields = [];
  List<ColumnInfo> missingRequiredFields = [];
  
  // Form layout data from API
  List<FormSection> _formSections = [];
  bool _isLoadingLayout = true;
  bool _isInitializing = true; 
  Map<String, List<Map<String, String>>> _lookupData = {};

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
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isInitializing = true; // Start in loading state
      _isLoadingLayout = true;
    });
    
    // First set up the controllers and basic data
    await _setupFields();

    // Then fetch any lookup data needed
    await _fetchLookupData();
    
    // Then fetch the layout (and wait for it)
    await _fetchFormLayout();
    
    // Only when everything is ready, mark initialization complete
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _fetchLookupData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      // Only fetch lead lookup data when creating an account
      if (widget.type == 'account') {
        final url = 'https://qa.api.bussus.com/v2/api/lookup/lead';
        print('🔍 Fetching lookup data for leads from: $url');
        
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          
          // Store the lookup data
          _lookupData['lead'] = data.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          }).toList();
          
          print('📋 Fetched ${_lookupData['lead']!.length} lead options');
          
          // Update the column info to use this lookup data
          for (int i = 0; i < _allFields.length; i++) {
            if (_allFields[i].name == 'lead') {
              // Create new values string from the fetched data - filter out any nulls
              String values = _lookupData['lead']!
                  .map((item) => item['name'] ?? '')  // Use empty string if name is null
                  .where((name) => name.isNotEmpty)    // Filter out empty strings
                  .join(',');
              
              // Update the column info with these values
              _allFields[i] = ColumnInfo(
                name: _allFields[i].name,
                label: _allFields[i].label,
                datatype: _allFields[i].datatype,
                required: _allFields[i].required,
                values: values,
              );
              
              // Also update dropdown cache - with non-nullable strings
              _dropdownOptionsCache['lead'] = _lookupData['lead']!
                  .map((item) => item['name'] ?? '')   // Convert nulls to empty strings
                  .where((name) => name.isNotEmpty)    // Filter out empty strings
                  .toList();
              break;
            }
          }
        } else {
          print('❌ Failed to load lead lookup data: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('🔥 Error fetching lookup data: $e');
    }
  }

  // Fetch form layout from API
  Future<void> _fetchFormLayout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      final url = 'https://qa.api.bussus.com/v2/api/${widget.type}/preview';
      print('🔍 Fetching form layout from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📊 Response status: ${response.statusCode}');
      print('📋 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Check if the response has a 'layout' property
        List<dynamic> layoutData;
        if (responseData is Map && responseData.containsKey('layout')) {
          layoutData = responseData['layout'];
        } else if (responseData is List) {
          layoutData = responseData;
        } else {
          throw Exception('Invalid response format');
        }
        
        // Now process the layout data
        List<FormSection> sections = [];
        for (var section in layoutData) {
          sections.add(FormSection(
            title: section['title'],
            fields: List<String>.from(section['fields']),
          ));
        }
        
        setState(() {
          _formSections = sections;
          _isLoadingLayout = false;
        });
        print('✅ Successfully parsed ${sections.length} form sections');
      } else {
        print('❌ Failed to load form layout: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        // Fall back to default layout
        _createDefaultLayoutFromExample();
      }
    } catch (e) {
      print('🔥 Error fetching form layout: $e');
      // Fallback to example layout on error
      _createDefaultLayoutFromExample();
    }
  }

  // Create layout using the example you provided
  void _createDefaultLayoutFromExample() {
    setState(() {
      _formSections = [
        FormSection(
          title: "Personal Details",
          fields: ["name", "email", "contact_number"],
        ),
        FormSection(
          title: "Other Details", 
          fields: ["lead", "customer_type", "customer_classification"],
        ),
      ];
      _isLoadingLayout = false;
      print('📝 Using hardcoded example layout');
    });
  }

  Future<void> _setupFields() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final allColumns = dataProvider.allColumns;
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

      _allFields = allColumns;

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

      // If API didn't return layout yet, create default layout
      
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
  
  Widget _buildErrorDisplay() {
    if (_error == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
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
            _allFields.any((col) => col.name == key && col.datatype.toLowerCase() == 'date'))) {

          // Only include non-empty date values
          if (controller.text.isNotEmpty) {
            formData[key] = controller.text; // Use as is, or convert if needed
          }
        }
        // Special handling for phone field
        else if (key == "phone") {
          // Only include non-empty phone values
          if (controller.text.isNotEmpty) {
            formData[key] = controller.text;
          }
          // Don't include empty phone values at all
        }
        // Handle other fields as before
        else {
          bool isRequired = _allFields.any((col) => col.name == key && col.required);
          if (isRequired) {
            formData[key] = controller.text;
          } else if (controller.text.isNotEmpty) {
            formData[key] = controller.text;
          }
        }
      });

      // Handle dropdown values
      for (var column in _allFields) {
        if (_hasDropdownValues(column)) {
          String value = _dropdownValues[column.name] ?? '';
          
          // Only include non-empty values that aren't placeholders
          if (value.isNotEmpty && !value.startsWith('--')) {
            // Special handling for lead field in accounts
            if (column.name == 'lead' && widget.type == 'account' && _lookupData.containsKey('lead')) {
              // Find the ID that corresponds to the selected name
              final selectedItem = _lookupData['lead']!.firstWhere(
                (item) => item['name'] == value,
                orElse: () => {'id': '', 'name': ''}
              );
              
              if (selectedItem['id']!.isNotEmpty) {
                formData[column.name] = selectedItem['id'];
                print('Adding lead ID value: ${selectedItem['id']} for name: $value');
              } else {
                formData[column.name] = value;
              }
            }
            // Handle other dropdown mappings as before
            else if (_dropdownMappings.containsKey(column.name) &&
                _dropdownMappings[column.name]!.containsKey(value)) {
              formData[column.name] = _dropdownMappings[column.name]![value];
            } else {
              formData[column.name] = value;
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
        String errorMessage = result['message'] ?? 'Failed to create item.';

        // Check for duplicate email error
        if (errorMessage.contains('duplicate key value') &&
            errorMessage.contains('email')) {
          errorMessage = 'This email is already registered. Please use a different email.';
        }

        setState(() {
          _error = errorMessage;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      String errorMessage = e.toString();

      // Check for specific error patterns in the exception
      if (errorMessage.contains('duplicate key value') &&
          errorMessage.contains('email')) {
        errorMessage = 'This email is already registered. Please use a different email.';
      } else if (errorMessage.contains('duplicate key value') &&
          errorMessage.contains('phone')) {
        errorMessage = 'This phone number is already registered. Please use a different phone number.';
      } else if (errorMessage.contains('duplicate key value')) {
        errorMessage = 'This record already exists in the system.';
      }

      setState(() {
        _error = errorMessage;
      });
      print('❌ Error creating new item: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
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
    // Use RichText for the label to have different color for the asterisk
    label: RichText(
      text: TextSpan(
        style: TextStyle(color: Colors.black, fontSize: 16), // Base style for all text
        children: [
          TextSpan(text: fieldLabel),
          if (isRequired)
            TextSpan(
              text: " *",
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.always, // Always show label above the field
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
    // Remove any other asterisks from suffix icons
  );
}

  Widget _buildForm() {
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
              
              // Form Fields grouped by sections from API
              ..._formSections.expand((section) {
                // Get fields for this section
                List<Widget> sectionWidgets = [];
                
                // Add section title and divider
                sectionWidgets.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                        ),
                        SizedBox(height: 4),
                        Divider(color: Colors.grey[400]),
                        SizedBox(height: 4),
                      ],
                    ),
                  ),
                );
                
                // Add fields that belong to this section
                for (String fieldName in section.fields) {
                  // Find the column info for this field
                  final columnInfo = _allFields.firstWhere(
                    (col) => col.name == fieldName,
                    orElse: () => ColumnInfo(
                      name: fieldName,
                      label: fieldName.replaceAll('_', ' ').capitalize(),
                      datatype: 'text',
                      required: false,
                      values: '',
                    ),
                  );
                  
                  sectionWidgets.add(_buildField(columnInfo, columnInfo.required));
                }
                
                return sectionWidgets;
              }).toList(),
             

              // Error message
              _buildErrorDisplay(),

            
              // Submit and Cancel buttons
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cancel button
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.black45),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Create button
                  ElevatedButton(
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
                ],
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
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              Icon(Icons.calendar_today),
            ],
          ),
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

    // For dropdown fields that need to submit ID instead of display value
    bool isLookupField = column.name == 'lead' && widget.type == 'account';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: currentValue?.isEmpty == true ? null : currentValue,
        // Remove hint text as requested
        hint: null,
        isExpanded: true,
        decoration: _inputDecoration(column.label, isRequired),
        dropdownColor: Colors.white, // Background color for dropdown items
        icon: Icon(Icons.arrow_drop_down),
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
              child: Text(''),
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
      body: _isInitializing // Check the initialization state
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(color: const Color.fromARGB(225, 17, 18, 18))),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: _buildForm(),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white, // Same color as the card
        elevation: 4, // Add shadow to match card
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


// Class to hold form section data from API
class FormSection {
  final String title;
  final List<String> fields;

  FormSection({required this.title, required this.fields});
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}