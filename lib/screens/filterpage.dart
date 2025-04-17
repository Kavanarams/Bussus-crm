import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import 'filter_logic.dart' as filter_logic;

/// A full screen filter page with improved UI using dialog for adding filters
class FilterPage extends StatefulWidget {
  final String type;

  const FilterPage({
    Key? key,
    required this.type,
  }) : super(key: key);

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  List<filter_logic.FilterCondition> _activeFilters = [];
  bool _isLoading = false;
  bool _hasChanges = false;
  // Track a temporary filter condition for the dialog
  filter_logic.FilterCondition? _tempFilterCondition;
  // Text controller for the dialog
  TextEditingController _dialogValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize filters from the current data provider filters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFilters();
    });
  }

  void _initializeFilters() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    // Debug: Print the current active filters from the provider
    print("DataProvider activeFilters: ${dataProvider.activeFilters}");
    
    // Check if filters are actually active
    final hasFilteredData = dataProvider.activeFilters.isNotEmpty;
    
    List<filter_logic.FilterCondition> currentFilters = [];
    
    if (hasFilteredData) {
      // Process each active filter
      dataProvider.activeFilters.forEach((field, value) {
        // Parse "operator:value" format
        if (value is String && value.contains(':')) {
          List<String> parts = value.split(':');
          if (parts.length >= 2) {
            String operatorStr = parts[0];
            // Join back parts[1:] to handle values that might contain colons
            String filterValue = parts.sublist(1).join(':');
            
            FilterOperator operator = FilterOperator.fromString(operatorStr);
            
            currentFilters.add(
              filter_logic.FilterCondition(
                field: field,
                operator: operator,
                value: filterValue, // This is the actual value without the operator prefix
              )
            );
            
            // Debug
            print("Extracted filter: field=$field, operator=$operatorStr, value=$filterValue");
          }
        }
      });
    }
    
    setState(() {
      _activeFilters = currentFilters;
    });
  }

  Future<void> _applyFilters() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    // Remove filters with empty values
    List<filter_logic.FilterCondition> validFilters = _activeFilters
        .where((filter) => filter.value.trim().isNotEmpty)
        .toList();
    
    // Convert FilterCondition objects to the format your API expects
    Map<String, String> newFilters = filter_logic.FilterManager.toSimpleFilters(validFilters);
    
    try {
      // Apply filters
      await dataProvider.applyFilters(newFilters, authProvider.token, widget.type);
      
      // Important: Reload the data after applying filters
      await dataProvider.loadData(widget.type, authProvider.token);
      
      setState(() {
        _isLoading = false;
      });
      
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying filters: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllFilters() async {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Clear filters on the server
      await dataProvider.clearFilters();
      
      // Important: Explicitly reload the data after clearing filters
      await dataProvider.loadData(widget.type, authProvider.token);
      
      // Reset the UI state
      setState(() {
        _activeFilters = [];
        _isLoading = false;
        _hasChanges = false;
      });
      
      // Only navigate back after all state updates are complete
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing filters: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }
    
  @override
  void dispose() {
    _dialogValueController.dispose();
    super.dispose();
  }
    
  // Determine if a field is a date field
  bool isDateField(String fieldName, List<filter_logic.ColumnInfo> allColumns) {
    final column = allColumns.firstWhere(
      (col) => col.name == fieldName,
      orElse: () => filter_logic.ColumnInfo(
        name: '', 
        type: '', 
        label: '', 
        display: true
      )
    );
    
    // Check if column type contains "date" or has a specific format
    return column.type.toLowerCase().contains('date') || 
           fieldName.toLowerCase().contains('date') ||
           fieldName.toLowerCase().contains('created_at') ||
           fieldName.toLowerCase().contains('updated_at');
  }
    
  // Get available operators for a field
  List<FilterOperator> getOperatorsForField(String fieldName, List<filter_logic.ColumnInfo> allColumns) {
    // Find the column info for this field
    final column = allColumns.firstWhere(
      (col) => col.name == fieldName,
      orElse: () => filter_logic.ColumnInfo(
        name: '', 
        type: '', 
        label: '', 
        display: true
      )
    );
    
    // Determine the field type
    String fieldType = 'text'; // default type
    
    if (column.type.isNotEmpty) {
      fieldType = column.type.toLowerCase();
    } else if (isDateField(fieldName, allColumns)) {
      fieldType = 'date';
    }
    
    // Get operators based on field type
    return filter_logic.getOperatorsForFieldType(fieldType);
  }

  // Method to show enhanced filter dialog
  void _showAddFilterDialog() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    List<filter_logic.ColumnInfo> allColumns = dataProvider.allColumns.map((col) => 
      filter_logic.ColumnInfo(
        name: col.name, 
        type: _getColumnType(col), 
        label: col.label, 
        display: _getColumnDisplay(col)
      )
    ).toList();

    // Update column labels
    Map<String, String> columnLabels = {};
    for (var col in dataProvider.allColumns) {
      columnLabels[col.name] = col.label;
    }
    
    // Initialize temporary filter condition
    if (dataProvider.visibleColumns.isNotEmpty) {
      String initialField = dataProvider.visibleColumns.first;
      _tempFilterCondition = filter_logic.FilterCondition(
        field: initialField,
        operator: getOperatorsForField(initialField, allColumns).first,
        value: '',
      );
      
      // Clear the dialog controller
      _dialogValueController.clear();
    } else {
      // No fields available
      return;
    }
    
    // Get the card background color for the dialog
    final Color cardBackgroundColor = Colors.white;
    
    // Show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDate = isDateField(_tempFilterCondition!.field, allColumns);
            // Get the field label for display
            final fieldLabel = columnLabels[_tempFilterCondition!.field] ?? _tempFilterCondition!.field;
            
            return AlertDialog(
              backgroundColor: cardBackgroundColor,
              title: Text('Add Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field section
                    Text('Field', style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.grey[700],
                    )),
                    SizedBox(height: 4),
                    _buildDialogFieldDropdown(allColumns, columnLabels, cardBackgroundColor, setDialogState),
                    SizedBox(height: 16),
                    
                    // Operator section
                    Text('Operator', style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.grey[700],
                    )),
                    SizedBox(height: 4),
                    _buildDialogOperatorDropdown(isDate, allColumns, cardBackgroundColor, setDialogState),
                    SizedBox(height: 16),
                    
                    // Value section
                    Text('Value', style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: Colors.grey[700],
                    )),
                    SizedBox(height: 4),
                    _buildDialogValueField(isDate, cardBackgroundColor, setDialogState),
                    
                    // Preview section
                    if (_tempFilterCondition!.value.isNotEmpty) ...[
                      SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Preview:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                _buildKeyValueText('Field', fieldLabel),
                                SizedBox(width: 8),
                                _buildKeyValueText('Operator', _tempFilterCondition!.operator.displayName),
                                SizedBox(width: 8),
                                _buildKeyValueText('Value', _tempFilterCondition!.value),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                // Cancel button - white with black text
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text('Cancel'),
                ),
                // Save button - blue with white text
                ElevatedButton(
                  onPressed: _tempFilterCondition!.value.trim().isNotEmpty ? () {
                    // Add the filter if value is not empty
                    setState(() {
                      _activeFilters.add(_tempFilterCondition!);
                      _hasChanges = true;
                    });
                    Navigator.of(context).pop();
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // Helper widget for displaying key-value text in preview
  Widget _buildKeyValueText(String key, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.blue[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  void _removeFilter(int index) {
    setState(() {
      _activeFilters.removeAt(index);
      _hasChanges = true;
    });
  }

  // Helper methods for dialog
  Widget _buildDialogFieldDropdown(
    List<filter_logic.ColumnInfo> allColumns,
    Map<String, String> columnLabels,
    Color backgroundColor,
    StateSetter setDialogState
  ) {
    // Get a list of field names from allColumns
    List<String> allFieldNames = allColumns
        .where((col) => col.display)
        .map((col) => col.name)
        .toList();
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: backgroundColor,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _tempFilterCondition!.field,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
          menuMaxHeight: 200,
          items: allFieldNames.map((field) {
            return DropdownMenuItem<String>(
              value: field,
              child: Text(columnLabels[field] ?? field, style: TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setDialogState(() {
                // Update the field and reset the operator based on the new field type
                List<FilterOperator> operators = getOperatorsForField(value, allColumns);
                _tempFilterCondition = filter_logic.FilterCondition(
                  field: value,
                  operator: operators.first,
                  value: '',
                );
                _dialogValueController.clear();
              });
            }
          },
          dropdownColor: backgroundColor,
        ),
      ),
    );
  }
  
  Widget _buildDialogOperatorDropdown(
    bool isDateField,
    List<filter_logic.ColumnInfo> allColumns,
    Color backgroundColor,
    StateSetter setDialogState
  ) {
    // Get appropriate operators based on field type
    final operators = getOperatorsForField(_tempFilterCondition!.field, allColumns);
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: backgroundColor,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FilterOperator>(
          value: _tempFilterCondition!.operator,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 20),
          menuMaxHeight: 200,
          items: operators.map((FilterOperator operator) {
            return DropdownMenuItem<FilterOperator>(
              value: operator,
              child: Text(operator.displayName, style: TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (FilterOperator? value) {
            if (value != null) {
              setDialogState(() {
                _tempFilterCondition = filter_logic.FilterCondition(
                  field: _tempFilterCondition!.field,
                  operator: value,
                  value: _tempFilterCondition!.value,
                );
              });
            }
          },
          dropdownColor: backgroundColor,
        ),
      ),
    );
  }
  
  Widget _buildDialogValueField(
    bool isDate, 
    Color backgroundColor,
    StateSetter setDialogState
  ) {
    if (isDate) {
      return InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
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
            // Format date as yyyy-MM-dd
            final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
            
            setDialogState(() {
              _tempFilterCondition = filter_logic.FilterCondition(
                field: _tempFilterCondition!.field,
                operator: _tempFilterCondition!.operator,
                value: formattedDate,
              );
              _dialogValueController.text = formattedDate;
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: backgroundColor,
          ),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tempFilterCondition!.value.isNotEmpty 
                    ? _tempFilterCondition!.value
                    : 'Select date...',
                style: TextStyle(
                  color: _tempFilterCondition!.value.isNotEmpty 
                      ? Colors.black 
                      : Colors.grey,
                  fontSize: 13,
                ),
              ),
              Icon(Icons.calendar_today, size: 18, color: Colors.blue),
            ],
          ),
        ),
      );
    } else {
      return TextField(
        controller: _dialogValueController,
        style: TextStyle(fontSize: 13),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          hintText: 'Enter value...',
          filled: true,
          fillColor: backgroundColor,
          suffixIcon: _dialogValueController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 16),
                  onPressed: () {
                    setDialogState(() {
                      _dialogValueController.clear();
                      _tempFilterCondition = filter_logic.FilterCondition(
                        field: _tempFilterCondition!.field,
                        operator: _tempFilterCondition!.operator,
                        value: '',
                      );
                    });
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setDialogState(() {
            _tempFilterCondition = filter_logic.FilterCondition(
              field: _tempFilterCondition!.field,
              operator: _tempFilterCondition!.operator,
              value: value,
            );
          });
        },
      );
    }
  }
  
  // Helper method to display detailed filter chip
  Widget _buildFilterChip(
    int index, 
    filter_logic.FilterCondition filter, 
    Map<String, String> columnLabels
  ) {
    // Get readable label for the field
    String fieldLabel = columnLabels[filter.field] ?? filter.field;
    
    return Container(
      margin: EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field label with title
                Row(
                  children: [
                    Text(
                      'Field: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      fieldLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // Operator with title
                Row(
                  children: [
                    Text(
                      'Operator: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      filter.operator.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                // Value with title
                Row(
                  children: [
                    Text(
                      'Value: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      filter.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 8),
            InkWell(
              onTap: () => _removeFilter(index),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.red[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
    
  // Helper method to safely access column type
  String _getColumnType(dynamic col) {
    try {
      return col.type?.toString() ?? "";
    } catch (e) {
      return "";
    }
  }
    
  // Helper method to safely access column display property
  bool _getColumnDisplay(dynamic col) {
    try {
      return col.display ?? true;
    } catch (e) {
      return true;
    }
  }
    
  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final cardBackgroundColor = Colors.white;
    
    // Create column info objects with the data we have
    List<filter_logic.ColumnInfo> allColumns = dataProvider.allColumns.map((col) => 
      filter_logic.ColumnInfo(
        name: col.name, 
        type: _getColumnType(col), 
        label: col.label, 
        display: _getColumnDisplay(col)
      )
    ).toList();
    
    // Update column labels
    Map<String, String> columnLabels = {};
    for (var col in dataProvider.allColumns) {
      columnLabels[col.name] = col.label;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Filter', style: TextStyle(
          color: Colors.white,
          fontSize: 18,
        )),
        backgroundColor: Colors.blue,
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.cleaning_services_outlined, color: Colors.white, size: 16),
            label: Text(
              'Clear All',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            onPressed: _clearAllFilters
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Filter count info - only show if filters exist
                if (_activeFilters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Active filters: ${_activeFilters.length}',
                              style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Card for filter display and actions
                Expanded(
                  child: Card(
                    elevation: 1,
                    margin: EdgeInsets.zero,
                    color: cardBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        // Applied filters section - scrollable wrap
                        if (_activeFilters.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Applied Filters',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8, // Horizontal space between chips
                                    runSpacing: 12, // Vertical space between lines
                                    children: _activeFilters.asMap().entries.map((entry) {
                                      return _buildFilterChip(entry.key, entry.value, columnLabels);
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.filter_alt_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No filters applied',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add filters to narrow down your results',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Action buttons section - fixed at bottom
                        Container(
                          decoration: BoxDecoration(
                            color: cardBackgroundColor,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                          ),
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Add Filter button
                              Expanded(
                                flex: 1,
                                child: TextButton.icon(
                                  icon: Icon(Icons.add_circle_outline, color: Colors.blue),
                                  label: Text('Add Filter', style: TextStyle(color: Colors.blue)),
                                  onPressed: _showAddFilterDialog,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    backgroundColor: cardBackgroundColor,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              // Apply Filters button
                              Expanded(
                                flex: 1,
                                child: ElevatedButton(
                                  onPressed: _activeFilters.isNotEmpty ? _applyFilters : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text(
                                    'Apply Filters',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}