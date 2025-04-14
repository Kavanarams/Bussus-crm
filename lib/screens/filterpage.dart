import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import 'filter_logic.dart' as filter_logic;

/// A full screen filter page with improved UI
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
  // late List<filter_logic.FilterCondition> _activeFilters;
  final Map<int, TextEditingController> _valueControllers = {};
  bool _isLoading = false;
  bool _hasChanges = false;

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
    // If no filters exist, add an empty one to start with
    if (currentFilters.isEmpty && dataProvider.visibleColumns.isNotEmpty) {
      _activeFilters = [
        filter_logic.FilterCondition(
          field: dataProvider.visibleColumns.first,
          operator: FilterOperator.equals,
          value: '',
        )
      ];
    } else {
      _activeFilters = currentFilters;
      
      // If there are no current filters but we have active filters in the provider,
      // we should ensure we have at least one filter condition
      if (_activeFilters.isEmpty && dataProvider.visibleColumns.isNotEmpty) {
        _activeFilters = [
          filter_logic.FilterCondition(
            field: dataProvider.visibleColumns.first,
            operator: FilterOperator.equals,
            value: '',
          )
        ];
      }
    }
    
    // Create and initialize text controllers with values from filter conditions
    _syncTextControllersWithFilters();
  });
}

// Improved synchronization of text controllers with filter values
void _syncTextControllersWithFilters() {
  // Dispose existing controllers
  _valueControllers.forEach((_, controller) => controller.dispose());
  _valueControllers.clear();
  
  // Create new controllers for each filter with their current values
  for (int i = 0; i < _activeFilters.length; i++) {
    _valueControllers[i] = TextEditingController(text: _activeFilters[i].value);
    // Debug
    print("Setting text controller $i to value: '${_activeFilters[i].value}'");
  }
}

Future<void> _applyFilters() async {
  final dataProvider = Provider.of<DataProvider>(context, listen: false);
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  setState(() {
    _isLoading = true;
  });
  
  // Update filter conditions from text controllers first
  for (int i = 0; i < _activeFilters.length; i++) {
    if (_valueControllers[i] != null) {
      _activeFilters[i] = filter_logic.FilterCondition(
        field: _activeFilters[i].field,
        operator: _activeFilters[i].operator,
        value: _valueControllers[i]!.text,
      );
    }
  }
  
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
      if (dataProvider.visibleColumns.isNotEmpty) {
        // Keep one empty filter with the first field
        String firstField = dataProvider.visibleColumns.first;
        _activeFilters = [
          filter_logic.FilterCondition(
            field: firstField,
            operator: FilterOperator.equals,
            value: '',
          )
        ];
        
        // Properly dispose existing controllers first
        _valueControllers.forEach((_, controller) => controller.dispose());
        _valueControllers.clear();
        
        // Create a new empty controller for the single remaining filter
        _valueControllers[0] = TextEditingController();
      }
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
    // Dispose all controllers
    _valueControllers.forEach((_, controller) => controller.dispose());
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

  void _addNewFilter() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    if (dataProvider.visibleColumns.isNotEmpty) {
      setState(() {
        final newIndex = _activeFilters.length;
        _activeFilters.add(
          filter_logic.FilterCondition(
            field: dataProvider.visibleColumns.first,
            operator: FilterOperator.equals,
            value: '',
          )
        );
        
        // Add a new controller for this filter
        _valueControllers[newIndex] = TextEditingController(text: '');
        _hasChanges = true;
      });
    }
  }

  void _removeFilter(int index) {
    setState(() {
      if (_activeFilters.length > 1) {
        _activeFilters.removeAt(index);
        
        // Remove and dispose the controller
        _valueControllers[index]?.dispose();
        
        // Reindex the controllers
        final Map<int, TextEditingController> newControllers = {};
        for (int i = 0; i < _activeFilters.length; i++) {
          if (i < index) {
            newControllers[i] = _valueControllers[i]!;
          } else {
            newControllers[i] = _valueControllers[i + 1]!;
          }
        }
        
        _valueControllers.clear();
        _valueControllers.addAll(newControllers);
        _hasChanges = true;
      }
    });
  }

  void _updateFilterField(int index, String value, List<filter_logic.ColumnInfo> allColumns) {
    setState(() {
      _activeFilters[index] = filter_logic.FilterCondition(
        field: value,
        operator: _activeFilters[index].operator,
        value: _activeFilters[index].value,
      );
      
      // Reset operator to match the new field type
      List<FilterOperator> operators = getOperatorsForField(value, allColumns);
      if (!operators.contains(_activeFilters[index].operator)) {
        _activeFilters[index] = filter_logic.FilterCondition(
          field: value,
          operator: operators.first,
          value: _activeFilters[index].value,
        );
      }
      _hasChanges = true;
    });
  }

  void _updateFilterOperator(int index, FilterOperator value) {
    setState(() {
      _activeFilters[index] = filter_logic.FilterCondition(
        field: _activeFilters[index].field,
        operator: value,
        value: _activeFilters[index].value,
      );
      _hasChanges = true;
    });
  }

  void _updateFilterValue(int index, String value) {
    setState(() {
      _activeFilters[index] = filter_logic.FilterCondition(
        field: _activeFilters[index].field,
        operator: _activeFilters[index].operator,
        value: value,
      );
      _hasChanges = true;
    });
  }

  Future<void> _selectDate(BuildContext context, int index) async {
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
      
      setState(() {
        _activeFilters[index] = filter_logic.FilterCondition(
          field: _activeFilters[index].field,
          operator: _activeFilters[index].operator,
          value: formattedDate,
        );
        
        // Update the text controller
        _valueControllers[index]?.text = formattedDate;
        _hasChanges = true;
      });
    }
  }
  
  @override
Widget build(BuildContext context) {
  final dataProvider = Provider.of<DataProvider>(context);
  
  // Create column info objects with the data we have
  List<filter_logic.ColumnInfo> allColumns = dataProvider.allColumns.map((col) => 
    filter_logic.ColumnInfo(
      name: col.name, 
      // Handle missing properties by using safe access
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
      title: Text('Filter', style: TextStyle(color: Colors.white,)),//fontWeight: FontWeight.bold
      backgroundColor: Colors.blue,
      elevation: 2,
      iconTheme: IconThemeData(color: Colors.white), // Make back arrow white
      actions: [
        TextButton.icon(
          icon: Icon(Icons.cleaning_services_outlined, color: Colors.white, size: 18),
          label: Text(
            'Clear All',
            style: TextStyle(color: Colors.white),
          ),
         onPressed: _clearAllFilters
        ),
      ],
    ),
    body: _isLoading 
      ? Center(child: CircularProgressIndicator())
      : Container(
          color: Colors.blue[50], // Light blue background
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter count and info
                      if (_activeFilters.any((filter) => filter.value.isNotEmpty))
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
                                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Active filters: ${_activeFilters.where((f) => f.value.isNotEmpty).length}',
                                    style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Filter conditions
                      ..._activeFilters.asMap().entries.map((entry) {
                        final index = entry.key;
                        final filter = entry.value;
                        final isDate = isDateField(filter.field, allColumns);
                        
                        return Card(
                          elevation: 1,
                          margin: EdgeInsets.only(bottom: 16),
                          color: Colors.white, // Pure white cards
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Filter ${index + 1}', 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Spacer(),
                                    if (_activeFilters.length > 1)
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                                        onPressed: () => _removeFilter(index),
                                        tooltip: 'Remove filter',
                                        iconSize: 20,
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                
                                // Field selector
                                Text('Field', style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                )),
                                SizedBox(height: 8),
                                _buildFieldDropdown(index, filter.field, allColumns, columnLabels),
                                SizedBox(height: 16),
                                
                                // Operator selector
                                Text('Operator', style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                )),
                                SizedBox(height: 8),
                                _buildOperatorDropdown(index, filter.operator, isDate, allColumns),
                                SizedBox(height: 16),
                                
                                // Value field
                                Text('Value', style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                )),
                                SizedBox(height: 8),
                                _buildValueField(index, filter.value, isDate),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      
                      // Add filter button
                      Center(
                        child: TextButton.icon(
                          icon: Icon(Icons.add_circle_outline, color: Colors.blue),
                          label: Text('Add Filter', style: TextStyle(color: Colors.blue)),
                          onPressed: _addNewFilter,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.blue.withOpacity(0.3)),
                            ),
                            backgroundColor: Colors.white, // White button background
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 100), // Extra space at bottom for scrolling
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    bottomNavigationBar: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Oval shape
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _hasChanges || _activeFilters.any((filter) => filter.value.isNotEmpty) 
                    ? _applyFilters 
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Oval shape
                  ),
                ),
                child: Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // Ensuring text is white
                  ),
                ),
              ),
            ),
          ],
        ),
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
  
  Widget _buildFieldDropdown(
    int index, 
    String currentValue, 
    List<filter_logic.ColumnInfo> allColumns,
    Map<String, String> columnLabels
  ) {
    // Get a list of field names from allColumns
    List<String> allFieldNames = allColumns
        .where((col) => col.display) // Only include display:true columns
        .map((col) => col.name)
        .toList();
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: allFieldNames.contains(currentValue) 
              ? currentValue 
              : allFieldNames.isNotEmpty ? allFieldNames.first : null,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue),
          items: allFieldNames.map((field) {
            return DropdownMenuItem<String>(
              value: field,
              child: Text(columnLabels[field] ?? field),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              _updateFilterField(index, value, allColumns);
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildOperatorDropdown(
    int index, 
    FilterOperator currentOperator, 
    bool isDateField,
    List<filter_logic.ColumnInfo> allColumns
  ) {
    // Get the field for this filter
    final field = _activeFilters[index].field;
    
    // Get appropriate operators based on field type
    final operators = getOperatorsForField(field, allColumns);
    
    // Make sure the current operator is in the available operators
    FilterOperator value = operators.contains(currentOperator) 
        ? currentOperator 
        : operators.first;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FilterOperator>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue),
          items: operators.map((FilterOperator operator) {
            return DropdownMenuItem<FilterOperator>(
              value: operator,
              child: Text(operator.displayName),
            );
          }).toList(),
          onChanged: (FilterOperator? value) {
            if (value != null) {
              _updateFilterOperator(index, value);
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildValueField(int index, String currentValue, bool isDate) {
    if (isDate) {
      return InkWell(
        onTap: () => _selectDate(context, index),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _valueControllers[index]?.text.isNotEmpty == true 
                    ? _valueControllers[index]!.text
                    : 'Select date...',
                style: TextStyle(
                  color: _valueControllers[index]?.text.isNotEmpty == true 
                      ? Colors.black 
                      : Colors.grey,
                ),
              ),
              Icon(Icons.calendar_today, size: 20, color: Colors.blue),
            ],
          ),
        ),
      );
    } else {
      return TextField(
        controller: _valueControllers[index],
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          hintText: 'Enter value...',
          suffixIcon: _valueControllers[index]!.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _valueControllers[index]!.clear();
                    _updateFilterValue(index, '');
                  },
                )
              : null,
        ),
        onChanged: (value) => _updateFilterValue(index, value),
      );
    }
  }
}