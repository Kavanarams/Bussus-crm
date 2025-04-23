import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'details_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_button_styles.dart';

class EditItemScreen extends StatefulWidget {
  final String type;
  final String itemId;

  EditItemScreen({required this.type, required this.itemId});

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  DynamicModel? _itemToEdit;
  List<Map<String, dynamic>> sections = [];
  Map<String, dynamic>? _layoutData;

  // Map to store form controllers
  final Map<String, TextEditingController> _controllers = {};
  
  // Map to store picklist values by field name
  final Map<String, List<String>> _picklistValues = {};
  
  // Map to store field data types
  final Map<String, String> _fieldDataTypes = {};

  // Define fallback picklist values for common fields
  final Map<String, List<String>> _fallbackPicklistValues = {
    'lead_status': [ 'New', 'Working-Contacted','follow Up', 'Unqualified', 'Closed Won', 'Closed Converted','Closed Rejected','Qualified','Lost'],
    'lead_source': [ 'Google Ads', 'Facebook', 'India Mart', 'Phone Enquiry', 'Purchased List','partner Refferal', 'Other'],
    'rating': ['Hot', 'Warm', 'Cold'],
    'industry': ['Technology', 'Healthcare', 'Finance', 'Education', 'Manufacturing', 'Retail', 'Other'],
    'priority': ['High', 'Medium', 'Low'],
    'stage': ['Discovery', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won', 'Closed Lost'],
    'status': ['Active', 'Inactive', 'Pending'],
  };

  // Add this method to your _EditItemScreenState class

void _ensurePicklistValuesExist() {
  // Check if we have any picklist fields without values
  _fieldDataTypes.forEach((fieldName, dataType) {
    if (dataType == 'picklist' && (!_picklistValues.containsKey(fieldName) || _picklistValues[fieldName]!.isEmpty)) {
      print('⚠️ Missing values for picklist field: $fieldName');
      
      // Check if we have fallback values
      if (_fallbackPicklistValues.containsKey(fieldName)) {
        _picklistValues[fieldName] = _fallbackPicklistValues[fieldName]!;
        print('✅ Applied fallback values for $fieldName: ${_picklistValues[fieldName]!.join(", ")}');
      } else {
        // Create generic values if no specific ones exist
        switch (fieldName.toLowerCase()) {
          case 'customer_type':
            _picklistValues[fieldName] = ['--none--', 'Influencer', 'Contractor', 'Consumer', 'Architect', 'Engineer'];
            break;
          case 'customer_classification':
            _picklistValues[fieldName] = ['--None--', 'Platinum', 'Gold', 'Diamond', 'regular'];
            break;
          case 'status':
          case 'account_status':
          case 'contact_status':
            _picklistValues[fieldName] = ['Active', 'Inactive', 'Pending'];
            break;
          case 'type':
          case 'account_type':
          case 'contact_type':
            _picklistValues[fieldName] = ['Standard', 'Premium', 'Enterprise', 'Other'];
            break;
          default:
            // Generic fallback for any unhandled picklist
            _picklistValues[fieldName] = ['Option 1', 'Option 2', 'Option 3'];
            break;
        }
        print('ℹ️ Created generic values for $fieldName: ${_picklistValues[fieldName]!.join(", ")}');
      }
    }
  });
}

  @override
  void initState() {
    super.initState();
    _loadItemDetails();
  }

  @override
  void dispose() {
    // Dispose all controllers when the widget is disposed
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadItemDetails() async {
  if (!_isInitialized) {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Find the item in the existing list
      _itemToEdit = dataProvider.items.firstWhere(
        (item) => item.id == widget.itemId,
        orElse: () => throw Exception('Item not found'),
      );

      // Fetch the item preview to get the layout and picklist values
      await _fetchItemPreview(authProvider.token);
      
      // Make sure all picklist fields have values
      _ensurePicklistValuesExist();

      // Initialize controllers with the current values
      for (var column in dataProvider.allColumns) {
        String value = _itemToEdit!.getStringAttribute(column.name, defaultValue: '');
        _controllers[column.name] = TextEditingController(text: value);
      }

      _isInitialized = true;
    } catch (e) {
      setState(() {
        _error = 'Failed to load item details: $e';
      });
      print('❌ Error loading item details: $_error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  Future<void> _fetchItemPreview(String token) async {
  try {
    final url = 'https://qa.api.bussus.com/v2/api/${widget.type}/preview?id=${widget.itemId}';
    
    print('🌐 Fetching item preview from: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      print('📄 Item preview response received successfully');
      
      // Debug API response structure
      print('📄 API response keys: ${responseData.keys.join(', ')}');
      
      // Store layout information
      if (responseData.containsKey('layout')) {
        _layoutData = responseData['layout'];
        
        // Extract sections from layout
        if (_layoutData != null && _layoutData!.containsKey('sections')) {
          sections = List<Map<String, dynamic>>.from(_layoutData!['sections']);
          print('📊 Loaded ${sections.length} sections from layout');
        }
      }
      
      // Process column metadata to find picklists
      if (responseData.containsKey('all_columns')) {
        List<dynamic> columns = responseData['all_columns'];
        print('📋 Processing ${columns.length} columns from API response');
        
        for (var column in columns) {
          // Store the data type for each field
          if (column['name'] != null && column['datatype'] != null) {
            String fieldName = column['name'];
            String dataType = column['datatype'];
            _fieldDataTypes[fieldName] = dataType;
            
            // Debug each column
            print('📋 Column: ${fieldName}, datatype: ${dataType}');
            
            // For picklists, debug more detailed info
            if (dataType == 'picklist') {
              print('🔍 Picklist field found: ${fieldName}');
              print('🔍 Picklist field structure: ${column.containsKey('picklist_values') ? 'Has picklist_values' : 'No picklist_values'} ${column['picklist_values'] is List ? '(List)' : column['picklist_values'] is Map ? '(Map)' : '(Unknown type)'}');
              
              if (column.containsKey('picklist_values')) {
                print('🔍 Raw picklist_values: ${column['picklist_values']}');
              }
              
              // Extract picklist values if available
              List<String> values = [];
              
              // Try to extract picklist values from the response
              if (column.containsKey('picklist_values')) {
                if (column['picklist_values'] is List) {
                  values = List<String>.from(column['picklist_values'].map((v) => 
                    v is String ? v : (v['value'] ?? v.toString())));
                } else if (column['picklist_values'] is Map) {
                  values = List<String>.from(column['picklist_values'].values);
                }
              }
              
              // If no values found in API, use fallback values
              if (values.isEmpty && _fallbackPicklistValues.containsKey(fieldName)) {
                values = _fallbackPicklistValues[fieldName]!;
                print('🔄 Using fallback values for ${fieldName}: ${values.join(", ")}');
              } else if (values.isEmpty) {
                print('⚠️ No values found for picklist ${fieldName} and no fallback available');
              }
              
              if (values.isNotEmpty) {
                _picklistValues[fieldName] = values;
                print('📊 Loaded ${values.length} picklist values for ${fieldName}: ${values.join(", ")}');
              }
            }
          }
        }
        
        // Print all picklist fields found
        print('📋 All picklist fields: ${_picklistValues.keys.join(', ')}');
      } else {
        print('⚠️ No all_columns found in API response');
      }
    } else {
      print('❌ Failed to fetch item preview: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error fetching item preview: $e');
  }
}

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Create a plain object without the "data" wrapper
      Map<String, dynamic> formData = {};

      // Add all field values directly to the formData object
      _controllers.forEach((key, controller) {
        // Don't include empty strings for optional fields
        if (controller.text.isNotEmpty) {
          formData[key] = controller.text;
        } else {
          // Include null for empty fields to clear them
          formData[key] = null;
        }
      });

      // Make sure to include the ID
      formData["id"] = widget.itemId;

      // Remove read-only fields
      formData.remove("created_by");
      formData.remove("created_date");
      formData.remove("last_modified_by");
      formData.remove("last_modified_date");

      // Send update request
      final result = await dataProvider.updateItem(
        widget.type,
        widget.itemId,
        formData,
        authProvider.token
      );

      if (result['success']) {
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Changes saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to the details screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(
              type: widget.type,
              itemId: widget.itemId,
            ),
          ),
        );
      } else {
        setState(() {
          _error = result['message'];
        });
        
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error ?? 'Failed to save changes'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error updating item: $e';
      });
      print('❌ Error updating item: $_error');
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final cardColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${_capitalizeFirstLetter(widget.type)}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.blue.shade50,
      body: _isLoading ?
        Center(child: CircularProgressIndicator()) :
        _buildForm(dataProvider, cardColor),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cardColor, // Match with card color
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

 Widget _buildForm(DataProvider dataProvider, Color cardColor) {
  if (_error != null) {
    return Center(child: Text(_error!, style: TextStyle(color: Colors.red)));
  }

  if (_itemToEdit == null) {
    return Center(child: Text('Item not found'));
  }

  // Get all columns
  final columns = dataProvider.allColumns;
  final columnMap = {for (var col in columns) col.name: col};

  return SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height - 180, // Account for AppBar, padding, and bottom nav
      ),
      child: Card(
        color: cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: IntrinsicHeight(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // This will push buttons to bottom
              children: [
                // Form content in a column
                Column(
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

                    if (sections.isEmpty)
                      Center(child: Text("No form sections available")),

                    // Sections with fields
                    ...sections.map((section) {
                      final title = section["title"] as String;
                      final fields = List<String>.from(section["fields"] ?? []);
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Title & Line Below It
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Divider(color: Colors.grey[400]),
                              ],
                            ),
                          ),
                          // Fields in this section
                          ...fields.map((fieldName) {
                            if (columnMap.containsKey(fieldName)) {
                              return _buildFormField(columnMap[fieldName]!, cardColor);
                            }
                            return SizedBox.shrink();
                          }).toList(),
                        ],
                      );
                    }).toList(),

                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),

                // Spacer that will push buttons to bottom when form content is short
                Spacer(),

                // Action buttons at bottom
                Column(
                  children: [
                    SizedBox(height: 24),
                    // Updated button row with global styles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: AppButtonStyles.secondaryButton,
                          child: Text("Cancel"),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveChanges,
                          style: AppButtonStyles.primaryButton,
                          child: Text("Save"),
                        ),
                      ),
                    ],
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

  Widget _buildFormField(ColumnInfo column, Color cardColor) {
    // Skip read-only fields
    if (_isReadOnlyField(column.name)) {
      return SizedBox.shrink();
    }
    
    // Make sure controller exists
    if (!_controllers.containsKey(column.name)) {
      _controllers[column.name] = TextEditingController();
    }

    bool isRequired = column.required;
    String fieldLabel = column.label;
    String fieldName = column.name;

    // Current value from controller
    String currentValue = _controllers[column.name]!.text;
    
    // Check if this field is a picklist based on our stored types
    bool isPicklist = _fieldDataTypes[column.name] == 'picklist';
    List<String>? picklistValues = _picklistValues[column.name];
    
    // Debug print for this field
    print('Field: $fieldName, Is picklist: $isPicklist, Values count: ${picklistValues?.length ?? 0}');
    
    // Handle picklist fields (if we have values for them)
    if (isPicklist && picklistValues != null && picklistValues.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black45),
                    borderRadius: BorderRadius.circular(4),
                    color: cardColor, // Match dropdown with card color
                  ),
                  child: DropdownButtonFormField<String>(
                    value: picklistValues.contains(currentValue) ? currentValue : null,
                    items: [
                      // Add an empty option for nullable fields
                      if (!isRequired)
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text('-- None --'),
                        ),
                      ...picklistValues.map((value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ],
                    onChanged: (newValue) {
                      setState(() {
                        _controllers[column.name]!.text = newValue ?? '';
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 8),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: Colors.black), // Changed to black
                    isExpanded: true,
                    dropdownColor: cardColor, // Match with card color
                  ),
                ),
                // Field label positioned on top of the border
                Positioned(
                  top: -10,
                  left: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    color: cardColor,
                    child: Text(
                      "$fieldLabel${isRequired ? ' *' : ''}", 
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // For date fields, use a date picker
    if (_isDateField(column.name)) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TextFormField(
              controller: _controllers[column.name],
              decoration: _inputDecoration("", isRequired).copyWith(
                suffixIcon: Icon(Icons.calendar_today, color: Colors.blue),
                contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 8),
              ),
              readOnly: true,
              onTap: () => _showDatePicker(column.name),
            ),
            // Field label positioned on top of the border
            Positioned(
              top: -10,
              left: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4),
                color: cardColor,
                child: Text(
                  "$fieldLabel${isRequired ? ' *' : ''}", 
                  style: TextStyle(
                    fontSize: 12, 
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For other fields, use TextFormField with inline label
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TextFormField(
            controller: _controllers[column.name],
            keyboardType: _getKeyboardType(column),
            decoration: _inputDecoration("", isRequired).copyWith(
              contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 8),
            ),
            validator: isRequired ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter ${fieldLabel.toLowerCase()}';
              }
              return null;
            } : null,
          ),
          // Field label positioned on top of the border
          Positioned(
            top: -10,
            left: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4),
              color: cardColor,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: fieldLabel,
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.black54, // Darker color for field labels
                        // fontWeight: FontWeight.w500, // Added weight to make it more visible
                      ),
                    ),
                    if (isRequired) TextSpan(
                      text: ' *',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red, // Red asterisk for required fields
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to determine if field is read-only
  bool _isReadOnlyField(String fieldName) {
    final readOnlyFields = [
      'created_by', 
      'created_date', 
      'last_modified_by', 
      'last_modified_date'
    ];
    return readOnlyFields.contains(fieldName);
  }
  
  // Helper method to determine if field is a date field
  bool _isDateField(String fieldName) {
    final dataType = _fieldDataTypes[fieldName]?.toLowerCase() ?? '';
    return fieldName.toLowerCase().contains('date') || 
           dataType == 'date' || 
           dataType == 'datetime';
  }
  
  // Show date picker for date fields
  Future<void> _showDatePicker(String fieldName) async {
    final DateTime now = DateTime.now();
    final currentValue = _controllers[fieldName]!.text;
    DateTime? initialDate;
    
    try {
      if (currentValue.isNotEmpty) {
        initialDate = DateTime.parse(currentValue);
      }
    } catch (e) {
      initialDate = now;
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _controllers[fieldName]!.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  // Helper method to determine keyboard type
  TextInputType _getKeyboardType(ColumnInfo column) {
    final name = column.name.toLowerCase();
    final datatype = _fieldDataTypes[column.name]?.toLowerCase() ?? column.datatype?.toLowerCase() ?? '';
    
    if (datatype == 'email') {
      return TextInputType.emailAddress;
    } else if (datatype == 'phone') {
      return TextInputType.phone;
    } else if (datatype == 'number' || datatype == 'currency' || 
              name.contains('amount') || name.contains('price')) {
      return TextInputType.number;
    } else if (datatype == 'url' || name.contains('website')) {
      return TextInputType.url;
    }
    
    return TextInputType.text;
  }

  InputDecoration _inputDecoration(String fieldLabel, bool isRequired) {
    return InputDecoration(
      floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black45),
        borderRadius: BorderRadius.circular(4),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black45),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(4),
      ),
      isDense: true,
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}