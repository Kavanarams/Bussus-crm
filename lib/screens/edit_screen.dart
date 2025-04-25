import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'details_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
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

        // Fetch the item preview via the DataProvider
        final previewData = await dataProvider.fetchItemPreview(
          widget.type,
          widget.itemId,
          authProvider.token,
        );
        
        // Store layout information
        if (previewData.containsKey('layout')) {
          _layoutData = previewData['layout'];
          
          // Extract sections from layout
          if (_layoutData != null && _layoutData!.containsKey('sections')) {
            sections = List<Map<String, dynamic>>.from(_layoutData!['sections']);
          }
        }
        
        // Process field data
        if (previewData.containsKey('all_columns')) {
          _processFieldData(previewData['all_columns']);
        }
        
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

  void _processFieldData(List<dynamic> columns) {
    for (var column in columns) {
      // Store the data type for each field
      if (column['name'] != null && column['datatype'] != null) {
        String fieldName = column['name'];
        String dataType = column['datatype'];
        _fieldDataTypes[fieldName] = dataType;
        
        // For picklists, extract values
        if (dataType == 'picklist') {
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
          
          if (values.isNotEmpty) {
            _picklistValues[fieldName] = values;
          }
        }
      }
    }
  }

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

  void _ensurePicklistValuesExist() {
    // Check if we have any picklist fields without values
    _fieldDataTypes.forEach((fieldName, dataType) {
      if (dataType == 'picklist' && (!_picklistValues.containsKey(fieldName) || _picklistValues[fieldName]!.isEmpty)) {
        print('⚠️ Missing values for picklist field: $fieldName');
        
        // Check if we have fallback values
        if (_fallbackPicklistValues.containsKey(fieldName)) {
          _picklistValues[fieldName] = _fallbackPicklistValues[fieldName]!;
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
        }
      }
    });
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
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.error,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${_capitalizeFirstLetter(widget.type)}',
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: Text(
              'SAVE',
              style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: _isLoading ?
        Center(child: CircularProgressIndicator()) :
        _buildForm(dataProvider, theme),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.cardBackground,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Label"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Leads"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Invoices"),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
        currentIndex: 1,
        selectedItemColor: AppColors.primary,
      ),
    );
  }

  Widget _buildForm(DataProvider dataProvider, ThemeData theme) {
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: AppColors.error)));
    }

    if (_itemToEdit == null) {
      return Center(child: Text('Item not found'));
    }

    // Get all columns
    final columns = dataProvider.allColumns;
    final columnMap = {for (var col in columns) col.name: col};

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppDimensions.spacingL),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 180, // Account for AppBar, padding, and bottom nav
        ),
        child: Card(
          elevation: AppDimensions.elevationM,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                          ),
                          margin: EdgeInsets.only(bottom: AppDimensions.spacingL),
                        ),
                      ),

                      if (sections.isEmpty)
                        Center(child: Text("No form sections available", style: AppTextStyles.bodyMedium)),

                      // Sections with fields
                      ...sections.map((section) {
                        final title = section["title"] as String;
                        final fields = List<String>.from(section["fields"] ?? []);
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Title & Line Below It
                            Padding(
                              padding: EdgeInsets.only(top: AppDimensions.spacingL, bottom: AppDimensions.spacingS),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTextStyles.subheading,
                                  ),
                                  SizedBox(height: AppDimensions.spacingXs),
                                  Divider(color: AppColors.divider),
                                ],
                              ),
                            ),
                            // Fields in this section
                            ...fields.map((fieldName) {
                              if (columnMap.containsKey(fieldName)) {
                                return _buildFormField(columnMap[fieldName]!, theme);
                              }
                              return SizedBox.shrink();
                            }).toList(),
                          ],
                        );
                      }).toList(),

                      if (_error != null)
                        Padding(
                          padding: EdgeInsets.only(top: AppDimensions.spacingL),
                          child: Text(
                            _error!,
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                    ],
                  ),

                  // Spacer that will push buttons to bottom when form content is short
                  Spacer(),

                  // Action buttons at bottom
                  Column(
                    children: [
                      SizedBox(height: AppDimensions.spacingXl),
                      // Button row with global styles
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
                          SizedBox(width: AppDimensions.spacingL),
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

  Widget _buildFormField(ColumnInfo column, ThemeData theme) {
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
    
    // Handle picklist fields (if we have values for them)
    if (isPicklist && picklistValues != null && picklistValues.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppDimensions.spacingXs),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                    color: AppColors.cardBackground,
                  ),
                  child: DropdownButtonFormField<String>(
                    value: picklistValues.contains(currentValue) ? currentValue : null,
                    items: [
                      // Add an empty option for nullable fields
                      if (!isRequired)
                        DropdownMenuItem<String>(
                          value: '',
                          child: Text('-- None --', style: AppTextStyles.bodyMedium),
                        ),
                      ...picklistValues.map((value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: AppTextStyles.bodyMedium),
                        );
                      }).toList(),
                    ],
                    onChanged: (newValue) {
                      setState(() {
                        _controllers[column.name]!.text = newValue ?? '';
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.fromLTRB(
                        AppDimensions.spacingM, 
                        AppDimensions.spacingL, 
                        AppDimensions.spacingM, 
                        AppDimensions.spacingS
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
                    isExpanded: true,
                    dropdownColor: AppColors.cardBackground,
                  ),
                ),
                // Field label positioned on top of the border
                Positioned(
                  top: -10,
                  left: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
                    color: AppColors.cardBackground,
                    child: Text(
                      "$fieldLabel${isRequired ? ' *' : ''}", 
                      style: AppTextStyles.labelText,
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
        padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TextFormField(
  controller: _controllers[column.name],
  decoration: InputDecoration(
    suffixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
    contentPadding: EdgeInsets.fromLTRB(
      AppDimensions.spacingM, 
      AppDimensions.spacingL, 
      AppDimensions.spacingM, 
      AppDimensions.spacingS
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    filled: true,
    fillColor: AppColors.cardBackground,
  ),
  readOnly: true,
  onTap: () => _showDatePicker(column.name),
),
            // Field label positioned on top of the border
            Positioned(
              top: -10,
              left: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
                color: AppColors.cardBackground,
                child: Text(
                  "$fieldLabel${isRequired ? ' *' : ''}", 
                  style: AppTextStyles.labelText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For other fields, use TextFormField with inline label
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TextFormField(
  controller: _controllers[column.name],
  keyboardType: _getKeyboardType(column),
  decoration: InputDecoration(
    contentPadding: EdgeInsets.fromLTRB(
      AppDimensions.spacingM, 
      AppDimensions.spacingL, 
      AppDimensions.spacingM, 
      AppDimensions.spacingS
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
      borderSide: BorderSide(color: AppColors.divider),
    ),
    filled: true,
    fillColor: AppColors.cardBackground,
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
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingXs),
              color: AppColors.cardBackground,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: fieldLabel,
                      style: AppTextStyles.labelText,
                    ),
                    if (isRequired) TextSpan(
                      text: ' *',
                      style: TextStyle(
                        fontSize: AppDimensions.textS,
                        color: AppColors.error,
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
              primary: AppColors.primary,
              onPrimary: AppColors.textWhite,
              onSurface: AppColors.textPrimary,
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

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}