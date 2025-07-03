import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';
import 'filter_logic.dart' as filter_logic;
import '../theme/app_snackbar.dart';

/// A full screen filter page with improved UI using dialog for adding filters
class FilterPage extends StatefulWidget {
  final String type;

  const FilterPage({
    super.key,
    required this.type,
  });

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  List<filter_logic.FilterCondition> _activeFilters = [];
  bool _isLoading = false;
  bool _hasChanges = false;
  filter_logic.FilterCondition? _tempFilterCondition;
  final TextEditingController _dialogValueController = TextEditingController();

  
  @override
  void initState() {
  super.initState();
  // Use addPostFrameCallback to ensure DataProvider is fully loaded
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeFilters();
  });
}
// Update the _initializeFilters method in your FilterPage

void _initializeFilters() {
  final dataProvider = Provider.of<DataProvider>(context, listen: false);
  
  print("🔍 Initializing filters from DataProvider");
  print("DataProvider activeFilters: ${dataProvider.activeFilters}");
  print("DataProvider hasActiveFilters: ${dataProvider.hasActiveFilters}");
  
  List<filter_logic.FilterCondition> currentFilters = [];
  
  // Check if there are active filters in the data provider
  if (dataProvider.hasActiveFilters && dataProvider.activeFilters.isNotEmpty) {
    print("✅ Found active filters, reconstructing filter conditions...");
    
    dataProvider.activeFilters.forEach((field, value) {
      // Handle both String and dynamic types
      String filterValue = value.toString();
      print("Processing filter: field=$field, value=$filterValue");
      
      if (filterValue.isNotEmpty) {
        if (filterValue.contains(':')) {
          // Handle "operator:value" format
          List<String> parts = filterValue.split(':');
          if (parts.length >= 2) {
            String operatorStr = parts[0];
            String actualValue = parts.sublist(1).join(':');
            
            FilterOperator operator = FilterOperator.fromString(operatorStr);
            
            currentFilters.add(
              filter_logic.FilterCondition(
                field: field,
                operator: operator,
                value: actualValue,
              )
            );
            
            print("✅ Added filter: field=$field, operator=$operatorStr, value=$actualValue");
          }
        } else {
          // Handle cases where there's no operator prefix (default to equals)
          currentFilters.add(
            filter_logic.FilterCondition(
              field: field,
              operator: FilterOperator.equals,
              value: filterValue,
            )
          );
          
          print("✅ Added default filter: field=$field, value=$filterValue");
        }
      }
    });
  } else {
    print("ℹ️ No active filters found in DataProvider");
  }
  
  setState(() {
    _activeFilters = currentFilters;
    // CRITICAL: Set _hasChanges to true if we have filters
    // This ensures the UI shows that filters are applied
    _hasChanges = currentFilters.isNotEmpty;
  });
  
  print("🎯 Initialized with ${currentFilters.length} filters, hasChanges: $_hasChanges");
  
  // IMPORTANT: Also check if the data provider has filtered items
  // This helps in cases where filters exist but UI state is inconsistent
  if (currentFilters.isEmpty && dataProvider.filteredItems.isNotEmpty) {
    print("⚠️ Found filtered items but no filter conditions. This might indicate a state inconsistency.");
  }
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
  
  print("🔄 Applying ${validFilters.length} filters: $newFilters");
  
  try {
    // Apply filters - this will update DataProvider's _activeFilters
    await dataProvider.applyFilters(newFilters, authProvider.token, widget.type);
    
    // CRITICAL: Don't reload data here as applyFilters already handles it
    // await dataProvider.loadData(widget.type, authProvider.token); // REMOVE THIS LINE
    
    setState(() {
      _isLoading = false;
      // Keep _hasChanges as true since we have active filters
      _hasChanges = validFilters.isNotEmpty;
    });
    
    // Show success message
    AppSnackBar.showSuccess(context, 'Filters applied successfully');
    
    // Navigate back with result
    Navigator.of(context).pop(true);
  } catch (e) {
    AppSnackBar.showError(context, 'Error applying filters: ${e.toString()}');
    
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
      
      // Reload the data after clearing filters
      await dataProvider.loadData(widget.type, authProvider.token);
      
      // Reset the UI state
      setState(() {
        _activeFilters = [];
        _isLoading = false;
        _hasChanges = false;
      });
      
      // Show success message
      AppSnackBar.showSuccess(context, 'All filters cleared');
      
      // Navigate back after clearing
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      
    } catch (e) {
      AppSnackBar.showError(context, 'Error clearing filters: ${e.toString()}');
      
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
  // Replace your _showAddFilterDialog method with this fixed version:
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
  
  // Show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final isDate = isDateField(_tempFilterCondition!.field, allColumns);
          // Get the field label for display
          final fieldLabel = columnLabels[_tempFilterCondition!.field] ?? _tempFilterCondition!.field;
          
          // Replace your entire AlertDialog with this fixed version:

return AlertDialog(
  backgroundColor: AppColors.cardBackground,
  title: Text('Add Filter', style: AppTextStyles.subheading),
  content: SizedBox(
    width: double.maxFinite,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field section
          Text('Field', style: AppTextStyles.fieldLabel),
          SizedBox(height: AppDimensions.spacingXs),
          _buildDialogFieldDropdown(allColumns, columnLabels, setDialogState),
          SizedBox(height: AppDimensions.spacingL),
          
          // Operator section
          Text('Operator', style: AppTextStyles.fieldLabel),
          SizedBox(height: AppDimensions.spacingXs),
          _buildDialogOperatorDropdown(isDate, allColumns, setDialogState),
          SizedBox(height: AppDimensions.spacingL),
          
          // Value section
          Text('Value', style: AppTextStyles.fieldLabel),
          SizedBox(height: AppDimensions.spacingXs),
          _buildDialogValueField(isDate, setDialogState),
          
          // Preview section
          if (_tempFilterCondition!.value.isNotEmpty) ...[
            SizedBox(height: AppDimensions.spacingXl),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppDimensions.spacingM),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Preview:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: AppDimensions.textS,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingS),
                  Text('Field: $fieldLabel', style: AppTextStyles.bodySmall),
                  SizedBox(height: AppDimensions.spacingXs),
                  Text('Operator: ${_tempFilterCondition!.operator.displayName}', style: AppTextStyles.bodySmall),
                  SizedBox(height: AppDimensions.spacingXs),
                  Text('Value: ${_tempFilterCondition!.value}', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
          
          // Add buttons directly in content
          SizedBox(height: AppDimensions.spacingXl),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: ElevatedButton(
                  onPressed: _tempFilterCondition!.value.trim().isNotEmpty ? () {
                    setState(() {
                      _activeFilters.add(_tempFilterCondition!);
                      _hasChanges = true;
                    });
                    Navigator.of(context).pop();
                  } : null,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: AppColors.textWhite,
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
        },
      );
    },
  );
}

// Also update the _buildKeyValueText helper method:
Widget _buildKeyValueText(String key, String value) {
  return Container(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key,
          style: AppTextStyles.labelText,
        ),
        SizedBox(height: AppDimensions.spacingXxs),
        Text(
          value,
          style: TextStyle(
            fontSize: AppDimensions.textS,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryDark,
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
    StateSetter setDialogState
  ) {
    // Get a list of field names from allColumns
    List<String> allFieldNames = allColumns
        .where((col) => col.display)
        .map((col) => col.name)
        .toList();
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        color: AppColors.cardBackground,
      ),
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingS),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _tempFilterCondition!.field,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: AppDimensions.iconM),
          menuMaxHeight: 200,
          items: allFieldNames.map((field) {
            return DropdownMenuItem<String>(
              value: field,
              child: Text(columnLabels[field] ?? field, style: AppTextStyles.bodyMedium),
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
          dropdownColor: AppColors.cardBackground,
        ),
      ),
    );
  }
  
  Widget _buildDialogOperatorDropdown(
    bool isDateField,
    List<filter_logic.ColumnInfo> allColumns,
    StateSetter setDialogState
  ) {
    // Get appropriate operators based on field type
    final operators = getOperatorsForField(_tempFilterCondition!.field, allColumns);
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        color: AppColors.cardBackground,
      ),
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingS),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FilterOperator>(
          value: _tempFilterCondition!.operator,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: AppDimensions.iconM),
          menuMaxHeight: 200,
          items: operators.map((FilterOperator operator) {
            return DropdownMenuItem<FilterOperator>(
              value: operator,
              child: Text(operator.displayName, style: AppTextStyles.bodyMedium),
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
          dropdownColor: AppColors.cardBackground,
        ),
      ),
    );
  }
  
  Widget _buildDialogValueField(
    bool isDate, 
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
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            color: AppColors.cardBackground,
          ),
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM, vertical: AppDimensions.spacingM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tempFilterCondition!.value.isNotEmpty 
                    ? _tempFilterCondition!.value
                    : 'Select date...',
                style: TextStyle(
                  color: _tempFilterCondition!.value.isNotEmpty 
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  fontSize: AppDimensions.textM,
                ),
              ),
              Icon(Icons.calendar_today, size: AppDimensions.iconS, color: AppColors.primary),
            ],
          ),
        ),
      );
    } else {
      return TextField(
        controller: _dialogValueController,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM, vertical: AppDimensions.spacingM),
          hintText: 'Enter value...',
          filled: true,
          fillColor: AppColors.cardBackground,
          suffixIcon: _dialogValueController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: AppDimensions.iconS),
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
  
  // UPDATED: New filter item widget that takes full width with divider
  Widget _buildFilterItem(
    int index, 
    filter_logic.FilterCondition filter, 
    Map<String, String> columnLabels
  ) {
    // Get readable label for the field
    String fieldLabel = columnLabels[filter.field] ?? filter.field;
    
    return Column(
      children: [
        // Add divider above all items except the first one
        if (index > 0)
          Divider(height: 1, thickness: 1, color: AppColors.divider),
          
        Container(
          width: double.infinity,
          color: AppColors.cardBackground,
          padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingM, horizontal: AppDimensions.spacingL),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter details - takes most of the space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field
                    Row(
                      children: [
                        Text(
                          'Field: ',
                          style: AppTextStyles.fieldLabel,
                        ),
                        Text(
                          fieldLabel,
                          style: AppTextStyles.fieldValue,
                        ),
                      ],
                    ),
                    SizedBox(height: AppDimensions.spacingXs),
                    
                    // Operator
                    Row(
                      children: [
                        Text(
                          'Operator: ',
                          style: AppTextStyles.fieldLabel,
                        ),
                        Text(
                          filter.operator.displayName,
                          style: AppTextStyles.fieldValue,
                        ),
                      ],
                    ),
                    SizedBox(height: AppDimensions.spacingXs),
                    
                    // Value
                    Row(
                      children: [
                        Text(
                          'Value: ',
                          style: AppTextStyles.fieldLabel,
                        ),
                        Text(
                          filter.value,
                          style: AppTextStyles.fieldValue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Delete button
              InkWell(
                onTap: () => _removeFilter(index),
                child: Container(
                  padding: EdgeInsets.all(AppDimensions.spacingS),
                  child: Icon(
                    Icons.delete_outline,
                    size: AppDimensions.iconL,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    
    // Create column info objects with the data we have
    // List<filter_logic.ColumnInfo> allColumns = dataProvider.allColumns.map((col) => 
    //   filter_logic.ColumnInfo(
    //     name: col.name, 
    //     type: _getColumnType(col), 
    //     label: col.label, 
    //     display: _getColumnDisplay(col)
    //   )
    // ).toList();
    
    // Update column labels
    Map<String, String> columnLabels = {};
    for (var col in dataProvider.allColumns) {
      columnLabels[col.name] = col.label;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Filter'),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.cleaning_services_outlined, color: AppColors.textWhite, size: AppDimensions.iconS),
            label: Text(
              'Clear All',
              style: TextStyle(color: AppColors.textWhite, fontSize: AppDimensions.textM),
            ),
            onPressed: _clearAllFilters
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : Container(
            color: AppColors.background,
            padding: EdgeInsets.all(AppDimensions.spacingL),
            child: Column(
              children: [
                // Filter count info - only show if filters exist
                if (_activeFilters.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppDimensions.spacingL),
                    child: Container(
                      padding: EdgeInsets.all(AppDimensions.spacingM),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, color: AppColors.primary, size: AppDimensions.iconM),
                          SizedBox(width: AppDimensions.spacingS),
                          Expanded(
                            child: Text(
                              'Active filters: ${_activeFilters.length}',
                              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Card for filter display and actions
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      side: BorderSide(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        // Applied filters section - scrollable list with full-width items
                        if (_activeFilters.isNotEmpty)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(AppDimensions.spacingL),
                                  child: Text(
                                    'Applied Filters',
                                    style: AppTextStyles.cardTitle,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _activeFilters.length,
                                    itemBuilder: (context, index) {
                                      return _buildFilterItem(
                                        index, 
                                        _activeFilters[index], 
                                        columnLabels
                                      );
                                    },
                                  ),
                                ),
                              ],
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
                                    color: AppColors.textHint,
                                  ),
                                  SizedBox(height: AppDimensions.spacingL),
                                  Text(
                                    'No filters applied',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: AppDimensions.textL,
                                    ),
                                  ),
                                  SizedBox(height: AppDimensions.spacingS),
                                  Text(
                                    'Add filters to narrow down your results',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: AppDimensions.textM,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Action buttons section - fixed at bottom
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            border: Border(
                              top: BorderSide(color: AppColors.divider, width: 1),
                            ),
                          ),
                          padding: EdgeInsets.all(AppDimensions.spacingL),
                          child: Row(
                            children: [
                              // Add Filter button
                              Expanded(
                                flex: 1,
                                child: TextButton.icon(
                                  icon: Icon(Icons.add_circle_outline, color: AppColors.primary),
                                  label: Text('Add Filter', style: AppTextStyles.actionText),
                                  onPressed: _showAddFilterDialog,
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                                    ),
                                    backgroundColor: AppColors.cardBackground,
                                  ),
                                ),
                              ),
                              SizedBox(width: AppDimensions.spacingL),
                              // Apply Filters button
                              Expanded(
                                flex: 1,
                                child: ElevatedButton(
                                  onPressed: _activeFilters.isNotEmpty ? _applyFilters : null,
                                  style: AppButtonStyles.primaryButton,
                                  child: Text(
                                    'Apply Filters',
                                    style: TextStyle(
                                      fontSize: AppDimensions.textM,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textWhite,
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