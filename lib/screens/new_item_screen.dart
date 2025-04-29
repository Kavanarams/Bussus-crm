import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NewItemScreen extends StatefulWidget {
  final String type;

  const NewItemScreen({super.key, required this.type});

  @override
  _NewItemScreenState createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  final Map<String, TextEditingController> _controllers = {};
  List<ColumnInfo> _allFields = [];
  List<FormSection> _formSections = [];
  bool _isInitializing = true;
  final Map<String, String> _dropdownValues = {};
  final Map<String, List<Map<String, String>>> _lookupData = {};
  final Map<String, List<String>> _dropdownOptionsCache = {};
  
  // Define the fields that need lookup data
  final List<String> _lookupFields = ['lead'];
  
  final Map<String, Map<String, String>> _dropdownMappings = {
    'customer_type': {
      'Engineer': 'EN',
      'Consumer': 'CO',
      'Contractor': 'CN',
      'Architect': 'AR',
      'Influencer': 'IN'
    }
  };

  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid build/layout issues
    Future.microtask(() => _initializeScreen());
  }

  Future<void> _initializeScreen() async {
    if (!mounted) return;
    
    setState(() {
      _isInitializing = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final token = authProvider.token;
      
      print("🔄 Starting form initialization for ${widget.type}");
      print("🔑 Token available: ${token.isNotEmpty}");
      
      // Setup fields first
      _allFields = await dataProvider.getColumns(widget.type);
      print("📊 Fields setup complete. Fields count: ${_allFields.length}");
      
      // Then fetch form layout
      _formSections = await dataProvider.getFormLayout(widget.type);
      print("📋 Form layout fetched. Sections count: ${_formSections.length}");
      
      // If we have layout but no fields, re-fetch fields using enhanced method
      if (_formSections.isNotEmpty && _allFields.isEmpty) {
        print("⚠️ Detected sections without fields, re-fetching fields from layout");
        _allFields = await dataProvider.getColumns(widget.type);
        print("📊 Fields re-setup complete. Fields count: ${_allFields.length}");
      }
      
      // Then fetch lookup data - This is where we need to focus
      await _fetchLookupData();
      print("🔍 Lookup data fetched");
      
      // Initialize controllers for all fields
      for (var field in _allFields) {
        _controllers[field.name] = TextEditingController();
        
        // Pre-populate dropdown options cache
        if (_hasDropdownValues(field)) {
          _dropdownOptionsCache[field.name] = _parseDropdownValues(field);
          print("🔽 Dropdown options for ${field.name}: ${_dropdownOptionsCache[field.name]}");
        }
      }
      
      // Only use default layout if we got empty data from both API calls
      if (_allFields.isEmpty && _formSections.isEmpty) {
        print("❌ API returned empty data, using default layout");
        _createDefaultLayoutFromExample();
      } 
      // If we have fields but no sections, create a default section
      else if (_allFields.isNotEmpty && _formSections.isEmpty) {
        print("⚠️ Creating default section for ${_allFields.length} fields");
        _formSections = [
          FormSection(
            title: "${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)} Information",
            fields: _allFields.map((field) => field.name).toList(),
          )
        ];
      }
      // If we have sections but still no fields, create default fields for them
      else if (_formSections.isNotEmpty && _allFields.isEmpty) {
        print("⚠️ Creating default fields for form sections");
        Set<String> fieldNames = {};
        for (var section in _formSections) {
          fieldNames.addAll(section.fields);
        }
        
        for (String fieldName in fieldNames) {
          // Convert field name to label (e.g., "email_address" -> "Email Address")
          String label = fieldName.replaceAll('_', ' ')
              .split(' ')
              .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
              .join(' ');
          
          // Guess datatype
          String datatype = 'text';
          if (fieldName.contains('email')) {
            datatype = 'email';
          } else if (fieldName.contains('phone')) datatype = 'phone';
          
          _allFields.add(ColumnInfo(
            name: fieldName,
            label: label,
            datatype: datatype,
            required: ['name', 'email', 'phone'].contains(fieldName),
            values: '',
          ));
          
          // Initialize controller
          _controllers[fieldName] = TextEditingController();
        }
        
        print("⚠️ Created ${_allFields.length} default fields");
      }
      else {
        print("✅ Using data from API: ${_allFields.length} fields, ${_formSections.length} sections");
      }
    } catch (e) {
      print('❌ Error during initialization: $e');
      // Create default sections as fallback
      _createDefaultLayoutFromExample();
      print("⚠️ Default layout created due to error. Sections: ${_formSections.length}, Fields: ${_allFields.length}");
    }
    
    if (!mounted) return;
    
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _setupFields() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      // We'll get columns directly from the getColumns method we added
      final columns = await dataProvider.getColumns(widget.type);
      
      if (columns.isEmpty) {
        print("Warning: No fields returned from API");
        return;
      }
      
      setState(() {
        _allFields = columns;
        
        // Initialize controllers for all fields
        for (var field in _allFields) {
          _controllers[field.name] = TextEditingController();
          
          // Pre-populate dropdown options cache
          if (_hasDropdownValues(field)) {
            _dropdownOptionsCache[field.name] = _parseDropdownValues(field);
          }
        }
      });
    } catch (e) {
      print("Error in _setupFields: $e");
      rethrow;
    }
  }
  
  Future<void> _fetchLookupData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      // Add your specific lookup fields here
      for (String field in _lookupFields) {
        // Fetch lookup data from API
        final response = await http.get(
          Uri.parse('https://qa.api.bussus.com/v2/api/lookup/$field'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final List<Map<String, String>> parsedData = data.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          }).toList();
          
          print("✅ Lookup data fetched for $field: ${parsedData.length} items");
          
          setState(() {
            _lookupData[field] = parsedData;
          });
        } else {
          print("⚠️ Failed to fetch lookup data for $field: ${response.statusCode}");
        }
      }
    } catch (e) {
      print("❌ Error fetching lookup data: $e");
    }
  }
  
  Future<void> _fetchFormLayout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      // We'll get the form layout directly from the getFormLayout method we added
      final sections = await dataProvider.getFormLayout(widget.type);
      
      if (sections.isEmpty) {
        print("Warning: No form layout returned from API");
        return;
      }
      
      setState(() {
        _formSections = sections;
      });
    } catch (e) {
      print("Error in _fetchFormLayout: $e");
      rethrow;
    }
  }
  
  void _createDefaultLayoutFromExample() {
    print("Creating default layout example...");
    
    // Clear existing data to prevent duplicates
    _allFields.clear();
    _formSections.clear();
    
    // Create some default fields
    _allFields = [
      ColumnInfo(name: "name", label: "Name", datatype: "text", required: true, values: ""),
      ColumnInfo(name: "email", label: "Email", datatype: "email", required: true, values: ""),
      ColumnInfo(name: "contact_number", label: "Contact Number", datatype: "phone", required: false, values: ""),
      ColumnInfo(name: "lead", label: "Lead", datatype: "text", required: false, values: ""),
      ColumnInfo(name: "customer_type", label: "Customer Type", datatype: "text", required: true, 
        values: "Engineer,Consumer,Contractor,Architect,Influencer"),
      ColumnInfo(name: "customer_classification", label: "Customer Classification", datatype: "text", required: false, 
        values: "A,B,C"),
    ];

    print("Default fields created: ${_allFields.length}");

    // Initialize controllers for all fields
    for (var field in _allFields) {
      _controllers[field.name] = _controllers[field.name] ?? TextEditingController();
      
      // Pre-populate dropdown options cache
      if (_hasDropdownValues(field)) {
        _dropdownOptionsCache[field.name] = _parseDropdownValues(field);
        print("Dropdown options for ${field.name}: ${_dropdownOptionsCache[field.name]}");
      }
    }

    // Create form sections
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
    
    print("Form sections created: ${_formSections.length}");
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Collect form data
      Map<String, dynamic> formData = {};
      _controllers.forEach((key, controller) {
        // Skip empty fields
        if (controller.text.isNotEmpty) {
          formData[key] = controller.text;
        }
      });
      
      // Handle dropdowns
      _dropdownValues.forEach((key, value) {
        if (value.isNotEmpty) {
          // For lookup fields, send the ID instead of display value
          if (_lookupFields.contains(key) && _lookupData.containsKey(key)) {
            // Find the matching ID for the selected display value
            final selectedItem = _lookupData[key]!.firstWhere(
              (item) => item['name'] == value,
              orElse: () => {'id': value, 'name': value}
            );
            formData[key] = selectedItem['id'];
          }
          // Check if we need to convert display value to actual value
          else if (_dropdownMappings.containsKey(key)) {
            formData[key] = _dropdownMappings[key]![value] ?? value;
          } else {
            formData[key] = value;
          }
        }
      });
      
      // Submit to API
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      final result = await dataProvider.createItem(
        widget.type,
        formData,
        authProvider.token,
      );
      
      if (result['success']) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)} created successfully')),
        );
        
        // Navigate back
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}'),
      ),
      body: SafeArea(
        child: _isInitializing 
            ? _buildLoadingIndicator()
            : _buildFormContent(),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading...', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    // Check if we have any form sections or fields
    if (_formSections.isEmpty && _allFields.isEmpty) {
      return Center(child: Text('No form data available'));
    }
    
    // If we have fields but no sections, create a default section
    if (_formSections.isEmpty && _allFields.isNotEmpty) {
      print("⚠️ Creating default section for ${_allFields.length} fields");
      _formSections = [
        FormSection(
          title: "Form Details",
          fields: _allFields.map((field) => field.name).toList(),
        )
      ];
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(AppDimensions.spacingL),
        child: Form(
          key: _formKey,
          child: Card(
            color: AppColors.cardBackground,
            elevation: AppDimensions.elevationM,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle divider
                  Center(
                    child: Container(
                      width: 30,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                      margin: EdgeInsets.only(bottom: AppDimensions.spacingL),
                    ),
                  ),
                  
                  // Form sections
                  ..._buildFormSections(),
                  
                  // Error message
                  if (_error != null) _buildErrorDisplay(),
                  
                  // Buttons
                  SizedBox(height: AppDimensions.spacingL),
                  _buildButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormSections() {
    List<Widget> sections = [];
    
    print("Building ${_formSections.length} form sections");
    
    for (int i = 0; i < _formSections.length; i++) {
      final section = _formSections[i];
      List<Widget> fieldWidgets = [];
      
      print("Section ${i+1}: ${section.title} with ${section.fields.length} fields");
      
      for (String fieldName in section.fields) {
        // Skip status field for leads type
        if (widget.type == 'lead' && fieldName == 'status') {
          print("⚠️ Skipping status field for leads type");
          continue;
        }
        
        // Find column info safely
        final columnInfoList = _allFields.where((col) => col.name == fieldName).toList();
        if (columnInfoList.isEmpty) {
          print("⚠️ Field not found in columns data: $fieldName");
          
          // Create a default field definition
          final defaultColumn = ColumnInfo(
            name: fieldName,
            label: fieldName.replaceAll('_', ' ')
                .split(' ')
                .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
                .join(' '),
            datatype: _guessDataType(fieldName),
            required: ['name', 'email', 'phone', 'status'].contains(fieldName),
            values: fieldName == 'status' ? 'New,In Progress,Completed,Cancelled' : '',
          );
          
          // Add to _allFields
          _allFields.add(defaultColumn);
          
          // Create controller
          if (!_controllers.containsKey(fieldName)) {
            _controllers[fieldName] = TextEditingController();
          }
          
          // Add field to widget list
          fieldWidgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _buildField(defaultColumn, defaultColumn.required),
            ),
          );
          
          print("⚠️ Created default field: ${defaultColumn.name} (${defaultColumn.datatype})");
        } else {
          final columnInfo = columnInfoList.first;
          print("Building field: ${columnInfo.name} (${columnInfo.datatype})");
          
          fieldWidgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _buildField(columnInfo, columnInfo.required),
            ),
          );
        }
      }
      
      if (fieldWidgets.isEmpty) {
        print("⚠️ No fields found for section: ${section.title}");
        continue; // Skip empty sections
      }
      
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Text(section.title, style: AppTextStyles.subheading),
            SizedBox(height: 8),
            Divider(color: AppColors.divider),
            SizedBox(height: 16),
            
            // Fields
            ...fieldWidgets,
            
            // Add space after each section
            SizedBox(height: 16),
          ],
        ),
      );
    }
    
    print("Built ${sections.length} form sections");
    return sections;
  }

  // Helper method to guess datatype based on field name
  String _guessDataType(String fieldName) {
    if (fieldName.contains('email')) return 'email';
    if (fieldName.contains('phone')) return 'phone';
    if (fieldName.contains('date')) return 'date';
    if (fieldName.contains('price') || fieldName.contains('amount')) return 'number';
    return 'text';
  }
    
  Widget _buildField(ColumnInfo column, bool isRequired) {
    // Ensure controller exists
    if (!_controllers.containsKey(column.name)) {
      _controllers[column.name] = TextEditingController();
    }
    
    if (column.datatype.toLowerCase() == 'date' || 
        column.name == 'created_date' ||
        column.name == 'last_modified_date') {
      return _buildDateField(column, isRequired);
    }
    
    // Check if this is a lookup field
    if (_lookupFields.contains(column.name) && _lookupData.containsKey(column.name)) {
      return _buildLookupDropdown(column, isRequired);
    }
    
    // Check for regular dropdown values
    if (_hasDropdownValues(column)) {
      List<String> options = _dropdownOptionsCache[column.name] ?? [];
      if (options.isNotEmpty) {
        return _buildDropdownField(column, options, isRequired);
      }
    }
    
    return _buildTextField(column, isRequired);
  }

  // New method to build lookup dropdown
  Widget _buildLookupDropdown(ColumnInfo column, bool isRequired) {
  // Get the lookup data for this field
  final lookupOptions = _lookupData[column.name] ?? [];
  
  // If we have no lookup data, fall back to a text field
  if (lookupOptions.isEmpty) {
    print("⚠️ No lookup options found for ${column.name}, falling back to text field");
    return _buildTextField(column, isRequired);
  }
  
  // Initialize dropdown value if not set
  if (!_dropdownValues.containsKey(column.name)) {
    _dropdownValues[column.name] = '';
  }
  
  return DropdownButtonFormField<String>(
    value: _dropdownValues[column.name]!.isEmpty ? null : _dropdownValues[column.name],
    decoration: _inputDecoration(column.label, isRequired),
    isExpanded: true,
    icon: Icon(Icons.arrow_drop_down),
    onChanged: (newValue) {
      setState(() {
        _dropdownValues[column.name] = newValue ?? '';
      });
    },
    items: [
      if (!isRequired)
        DropdownMenuItem<String>(value: '', child: Text('-- Select ${column.label} --')),
      ...lookupOptions.map((option) => 
        DropdownMenuItem<String>(
          value: option['name'] ?? '',
          // Fix: providing a default empty string if option['name'] is null
          child: Text(option['name'] ?? '', overflow: TextOverflow.ellipsis),
        )
      ),
    ],
    validator: isRequired ? (value) {
      if (value == null || value.isEmpty) {
        return 'Please select ${column.label}';
      }
      return null;
    } : null,
  );
}
  // Simplified error display
  Widget _buildErrorDisplay() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
        ],
      ),
    );
  }

  // Simplified buttons row
  Widget _buildButtons() {
    return Center(
      child: Table(
        defaultColumnWidth: IntrinsicColumnWidth(),
        children: [
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: AppButtonStyles.secondaryButton,
                  child: Text('Cancel'),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: AppButtonStyles.primaryButton,
                  child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Create ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bottom navigation bar
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.cardBackground,
      elevation: AppDimensions.elevationM,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Label"),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Leads"),
        BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Invoices"),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
      ],
      currentIndex: 1,
      selectedItemColor: AppColors.primary,
    );
  }

  // Implementation for the input fields
  Widget _buildTextField(ColumnInfo column, bool isRequired) {
    final controller = _controllers[column.name] ?? TextEditingController();
    
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(column.label, isRequired),
      keyboardType: _getKeyboardType(column.datatype),
      validator: isRequired ? (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter ${column.label}';
        }
        return null;
      } : null,
    );
  }

  Widget _buildDateField(ColumnInfo column, bool isRequired) {
    final controller = _controllers[column.name] ?? TextEditingController();
    
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(column.label, isRequired).copyWith(
        suffixIcon: Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );

        if (pickedDate != null) {
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
    );
  }

  Widget _buildDropdownField(ColumnInfo column, List<String> options, bool isRequired) {
    // Initialize with empty string if not set yet
    if (!_dropdownValues.containsKey(column.name)) {
      _dropdownValues[column.name] = '';
    }
    
    // Handle special cases for common fields
    if (options.isEmpty && column.name == 'status') {
      options = ['New', 'In Progress', 'Completed', 'Cancelled'];
    }
    
    // If required and no value selected yet, try to select the first valid option
    if (isRequired && _dropdownValues[column.name]!.isEmpty && options.isNotEmpty) {
      // Try to find first non-placeholder option or default to first
      _dropdownValues[column.name] = options.firstWhere(
        (opt) => !opt.startsWith('--'), 
        orElse: () => options.first
      );
    }
    
    return DropdownButtonFormField<String>(
      value: _dropdownValues[column.name]!.isEmpty ? null : _dropdownValues[column.name],
      decoration: _inputDecoration(column.label, isRequired),
      isExpanded: true,
      icon: Icon(Icons.arrow_drop_down),
      onChanged: (newValue) {
        setState(() {
          _dropdownValues[column.name] = newValue ?? '';
        });
      },
      items: [
        if (!isRequired)
          DropdownMenuItem<String>(value: '', child: Text('-- Select ${column.label} --')),
        ...options.map((option) => 
          DropdownMenuItem<String>(
            value: option,
            child: Text(option, overflow: TextOverflow.ellipsis),
          )
        ),
      ],
      validator: isRequired ? (value) {
        if (value == null || value.isEmpty) {
          return 'Please select ${column.label}';
        }
        return null;
      } : null,
    );
  }

  // Helper methods
  InputDecoration _inputDecoration(String fieldLabel, bool isRequired) {
    return InputDecoration(
      label: RichText(
        text: TextSpan(
          style: AppTextStyles.fieldLabel,
          children: [
            TextSpan(text: fieldLabel),
            if (isRequired)
              TextSpan(
                text: " *",
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: EdgeInsets.symmetric(
        vertical: AppDimensions.spacingS,
        horizontal: AppDimensions.spacingM,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      // hintText: fieldLabel.toLowerCase() == 'phone' ? 'Must be unique' : null,
    );
  }

  TextInputType _getKeyboardType(String dataType) {
    switch (dataType.toLowerCase()) {
      case 'number': case 'integer': case 'decimal': return TextInputType.number;
      case 'email': return TextInputType.emailAddress;
      case 'phone': return TextInputType.phone;
      case 'url': return TextInputType.url;
      case 'date': return TextInputType.datetime;
      default: return TextInputType.text;
    }
  }

  bool _hasDropdownValues(ColumnInfo column) {
    return column.values.isNotEmpty;
  }

  List<String> _parseDropdownValues(ColumnInfo column) {
    // Your existing implementation
    if (_dropdownOptionsCache.containsKey(column.name)) {
      return _dropdownOptionsCache[column.name]!;
    }

    List<String> result = [];
    if (column.values.isNotEmpty) {
      try {
        if (column.values.startsWith('[')) {
          result = List<String>.from(json.decode(column.values));
        } else {
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
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}                                   