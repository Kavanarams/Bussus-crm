import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dynamic_model.dart';

class FormSection {
  final String title;
  final List<String> fields;

  FormSection({
    required this.title,
    required this.fields,
  });

  factory FormSection.fromJson(Map<String, dynamic> json) {
    return FormSection(
      title: json['title'] ?? '',
      fields: List<String>.from(json['fields'] ?? []),
    );
  }
}

enum FilterOperator {
  equals('equals'),
  notEquals('not_equals'),
  contains('contains'),
  notContains('not_contains'),
  greaterThan('greater_than'),
  lessThan('less_than'),
  greaterThanOrEqual('greater_than_or_equal'),
  lessThanOrEqual('less_than_or_equal'),
  startsWith('starts_with'),
  before('before'),
  after('after');

  final String apiValue;
  const FilterOperator(this.apiValue);
   // Add a display name getter
  String get displayName {
    switch (this) {
      case FilterOperator.equals: return 'Equals';
      case FilterOperator.notEquals: return 'Not Equals';
      case FilterOperator.contains: return 'Contains';
      case FilterOperator.notContains: return 'Not Contains';
      case FilterOperator.greaterThan: return 'Greater Than';
      case FilterOperator.greaterThanOrEqual: return 'Greater Than or Equal';
      case FilterOperator.lessThan: return 'Less Than';
      case FilterOperator.lessThanOrEqual: return 'Less Than or Equal';
      case FilterOperator.startsWith: return 'Starts With';
      case FilterOperator.before: return 'Before';
      case FilterOperator.after: return 'After';
    }
  }
  
  // Parse string to FilterOperator
  static FilterOperator fromString(String value) {
    return FilterOperator.values.firstWhere(
      (op) => op.apiValue == value,
      orElse: () => FilterOperator.equals,
    );
  }
}

class DataProvider with ChangeNotifier {
  List<DynamicModel> _items = [];
  List<DynamicModel> _filteredItems = [];
  bool _isLoading = false;
  String? _error;
  ApiResponse? _currentResponse;
  String? _currentListViewId;// Store current list view ID
  String _token = '';
  String _type = '';

  // Filter and sort state
  Map<String, dynamic> _activeFilters = {};
  String? _sortColumn;
  bool _sortAscending = true;
  // Add this getter to your DataProvider class
ObjectInfo? get objectMetadata => _currentResponse?.object;

  // Remove context dependency
  DataProvider();
  bool _sortingActive = false;
List<DynamicModel> _originalItems = []; // To store original order if needed

// Add these methods to your DataProvider class

// Getter and setter for _sortingActive flag
bool get sortingActive => _sortingActive;
void setSortingActive(bool value) {
  _sortingActive = value;
  if (value) {
    // When activating sorting, store the original items
    _originalItems = List.from(_items);
  }
  _safeNotifyListeners();
}

  // FIX: Updated getter to correctly handle filtered vs unfiltered state

List<DynamicModel> get items {
  // If filter is active but filteredItems is empty, show loading or empty state
  if (_activeFilters.isNotEmpty) {
    return _filteredItems;
  } else {
    return _items;
  }
}

// Add this getter to your DataProvider class
List<DynamicModel> get filteredItems {
  return _filteredItems;
}

// Make this method public in DataProvider to allow direct access
Map<String, String> buildFilterQueryParams() {
  Map<String, String> queryParams = {};
  
  _activeFilters.forEach((field, value) {
    // Check if the value contains an operator prefix (like eq:value)
    if (value is String && value.contains(':')) {
      queryParams[field] = value;
    } else {
      // Default to equals operator if none specified
      queryParams[field] = 'equals:$value';
    }
  });
  
  return queryParams;
}
  bool get isLoading => _isLoading;
  String? get error => _error;
  ApiResponse? get currentResponse => _currentResponse;
  List<ColumnInfo> get allColumns => _currentResponse?.allColumns ?? [];
  List<String> get visibleColumns => _currentResponse?.visibleColumns ?? [];
  String? get currentListViewId => _currentListViewId;

  // Getters for filter and sort state
  Map<String, dynamic> get activeFilters => _activeFilters;
  String? get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;


  // Add this to your DataProvider class
  void setState(Function() updateFunction) {
    // Run the update function
    updateFunction();
    
    // Notify listeners after the state changes
    _safeNotifyListeners();
  }

  // Add this method to your DataProvider class if it doesn't exist already
String? getColumnLabel(String columnName) {
  // Based on your original code, it seems you're using a map of column labels
  // Check if there's a label for this column
  for (var column in allColumns) {
    if (column.name == columnName) {
      return column.label;
    }
  }
  return columnName; // Default to the column name if no label is found
}

  void _safeNotifyListeners() {
    // Only notify if it's safe to do so
    try {
      notifyListeners();
    } catch (e) {
      print('⚠️ Skipped unsafe notifyListeners(): $e');
      // Schedule the notification for the next frame instead
      Future.microtask(() => notifyListeners());
    }
  }

  // Updated to require token as a parameter
  Future<void> loadData(String type, String token) async {
  _token = token;
  _type = type;

  // If sorting is active, save the current sort settings
  String? savedSortColumn = _sortColumn;
  bool savedSortAscending = _sortAscending;
  bool wasSortingActive = _sortingActive;

  // Only reset these if sorting is not active
  if (!_sortingActive) {
    _items = [];
    _filteredItems = [];
    _activeFilters = {};
    _originalItems = [];
  }
  
  _error = null;
  _currentListViewId = null;

  _isLoading = true;
  _safeNotifyListeners();

  try {
    String endpoint = 'https://qa.api.bussus.com/v2/api/listview/$type?limit=1000';
    print('🌐 Fetching data from: $endpoint');
    print('🔑 Using token: ${token.isNotEmpty ? '${token.substring(0, 10)}...' : 'Empty token'}');
    print('🔀 Active sorting: $_sortingActive');

    // Check if token exists
    if (token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _items = [];
      _filteredItems = [];
      _isLoading = false;
      _safeNotifyListeners();
      return;
    }

    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Response status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

      // Store the list view ID for future filter requests
      _currentListViewId = apiResponse.listview.id;
      _currentResponse = apiResponse;
      _error = null;

      // Only replace items if sorting is not active
      if (!wasSortingActive) {
        _items = apiResponse.data;
        _filteredItems = [];
        _originalItems = List.from(_items); // Store original order
        
        // Apply default sorting if no specific sort is active
        if (_sortColumn == null) {
          _sortByCreationDate();
        }
      } else {
        // If sorting was active, store the new data but keep our sorted order
        print('🔀 Preserving sort order while updating data');
        _originalItems = apiResponse.data;
        
        // Re-apply the sort with the existing settings
        _sortColumn = savedSortColumn;
        _sortAscending = savedSortAscending;
        if (_sortColumn != null) {
          _applySorting();
        }
      }

      print('📊 Loaded ${_items.length} items');
      print('📊 Visible columns: ${apiResponse.visibleColumns}');
      print('📊 All columns count: ${apiResponse.allColumns.length}');
      print('📊 ListView ID: $_currentListViewId');
    } else if (response.statusCode == 401) {
      _error = 'Authentication expired. Please log in again.';
      _items = [];
      _filteredItems = [];
      _originalItems = [];
    } else if (response.statusCode == 404) {
      _error = 'No data found for this view.';
      _items = [];
      _filteredItems = [];
      _originalItems = [];
    } else {
      _error = 'Failed to load data. Status code: ${response.statusCode}';
      _items = [];
      _filteredItems = [];
      _originalItems = [];
    }
  } catch (e) {
    _error = 'Error occurred: $e';
    _items = [];
    _filteredItems = [];
    _originalItems = [];
    print('❌ Error fetching data: $e');
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}

  // Extract sorting by creation date into a separate method for reuse
  void _sortByCreationDate() {
    print('📅 Sorting ${_items.length} items by creation date');

    // Sort by creation date (newest first)
    _items.sort((a, b) {
      String dateA = a.getStringAttribute('created_date');
      String dateB = b.getStringAttribute('created_date');

      if (dateA.isNotEmpty && dateB.isNotEmpty) {
        // Try parsing as DateTime for more accurate comparison
        try {
          DateTime dtA = DateTime.parse(dateA);
          DateTime dtB = DateTime.parse(dateB);
          return dtB.compareTo(dtA); // Descending order (newest first)
        } catch (e) {
          // Fallback to string comparison if parsing fails
          return dateB.compareTo(dateA);
        }
      }
      return 0;
    });

    if (_items.isNotEmpty) {
      print('📅 After sorting: First item created date: ${_items.first.getStringAttribute('created_date')}');
    }
  }

  Future<void> fetchData(String endpoint, String token) async {
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      if (endpoint.contains('?')) {
        endpoint = '$endpoint&limit=1000'; // Add high limit
      } else {
        endpoint = '$endpoint?limit=1000'; // Add high limit
      }
      print('🌐 Fetching data from: $endpoint');
      print('🔑 Using token: ${token.isNotEmpty ? '${token.substring(0, 10)}...' : 'Empty token'}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _items = [];
        _filteredItems = [];
        _isLoading = false;
        _safeNotifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📤 Response status code: ${response.statusCode}');
      print('📤 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

        // Store the list view ID for future filter requests
        _currentListViewId = apiResponse.listview.id;

        _items = apiResponse.data;
        _filteredItems = [];
        _currentResponse = apiResponse;
        _error = null;

        // Reset filters and sorting when new data is loaded
        _activeFilters = {};
        _sortColumn = null;

        print('📊 Loaded ${_items.length} items');
        print('📊 Visible columns: ${apiResponse.visibleColumns}');
        print('📊 All columns count: ${apiResponse.allColumns.length}');
        print('📊 ListView ID: $_currentListViewId');
      } else if (response.statusCode == 401) {
        _error = 'Authentication expired. Please log in again.';
        _items = [];
        _filteredItems = [];
      } else if (response.statusCode == 404) {
        _error = 'No data found for this view.';
        _items = [];
        _filteredItems = [];
      } else {
        _error = 'Failed to load data. Status code: ${response.statusCode}';
        _items = [];
        _filteredItems = [];
      }
    } catch (e) {
      _error = 'Error occurred: $e';
      _items = [];
      _filteredItems = [];
      print('❌ Error fetching data: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
  
  Future<void> applyFilterWithOperator(String field, FilterOperator operator, String value) async {
    Map<String, String> filters = {};
    if (value.isNotEmpty) {
      filters[field] = '${operator.apiValue}:$value';
    }

    await applyFilters(filters, _token, _type);
  }


  Future<void> applyFilter(String field, String? value) async {
    Map<String, String> filters = {};
    if (value != null && value.isNotEmpty) {
      filters[field] = 'equals:$value';  // Use explicit equals operator
    }

    await applyFilters(filters, _token, _type);
  }

  // FIX: Updated to correctly handle filtered results
  Future<void> applyFilters(Map<String, String> filters, String token, String type) async {
  _isLoading = true;
  _activeFilters = Map<String, dynamic>.from(filters);
  _safeNotifyListeners();

  try {
    // Only proceed if we have a valid list view ID
    if (_currentListViewId == null) {
      _error = 'No list view ID available for filtering';
      _isLoading = false;
      _safeNotifyListeners();
      return;
    }

    // Build the filters array in the required format
    List<Map<String, String>> filtersList = [];
    filters.forEach((field, value) {
      if (value.isNotEmpty) {
        // Check if value contains operator (format: "operator:value")
        if (value.contains(':')) {
          final parts = value.split(':');
          final operator = parts[0];
          final filterValue = parts.sublist(1).join(':');
          
          filtersList.add({
            'field': field,
            'operator': operator,
            'value': filterValue
          });
        } else {
          // Default to equals if no operator specified
          filtersList.add({
            'field': field,
            'operator': 'equals',
            'value': value
          });
        }
      }
    });

    // Construct the payload as per API requirements
    final Map<String, dynamic> payload = {
      'data': {
        'filters': filtersList,
        'filter_logic': '',
        'id': _currentListViewId
      }
    };

    print('🔍 Applying filters with payload: ${json.encode(payload)}');

    // Send the PATCH request
    final response = await http.patch(
      Uri.parse('https://qa.api.bussus.com/v2/api/listview'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    print('📤 Filter response status code: ${response.statusCode}');
    print('📤 Filter response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

      // Critical fix - update both filtered items and the main items list
      _filteredItems = apiResponse.data;
      _items = _filteredItems; // This ensures data is available immediately
      _currentResponse = apiResponse;
      _error = null;

      print('📊 Applied filters. Items count after filtering: ${_filteredItems.length}');
    } else {
      _error = 'Failed to apply filters. Status code: ${response.statusCode}';
      print('❌ Error applying filters: ${response.body}');
    }
  } catch (e) {
    _error = 'Error applying filters: $e';
    print('❌ Error applying filters: $e');
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}
  
  // FIX: Updated to properly handle clearing filters
Future<void> clearFilters() async {
  _isLoading = true;
  _safeNotifyListeners();

  try {
    // Only proceed if we have a valid list view ID
    if (_currentListViewId == null) {
      _error = 'No list view ID available for clearing filters';
      _isLoading = false;
      _activeFilters = {};
      _filteredItems = [];
      _safeNotifyListeners();
      return;
    }

    // Create empty filter payload as per API requirements
    final Map<String, dynamic> payload = {
      'data': {
        'filters': [],
        'filter_logic': '',
        'id': _currentListViewId
      }
    };

    print('🔍 Clearing filters on server for listview: $_currentListViewId');

    // Send the PATCH request
    final response = await http.patch(
      Uri.parse('https://qa.api.bussus.com/v2/api/listview'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    print('📤 Clear filter response status code: ${response.statusCode}');
    print('📤 Clear filter response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

      // Critical fix - clear state completely
      _activeFilters = {};
      _filteredItems = [];
      _items = apiResponse.data;
      _currentResponse = apiResponse;
      _error = null;

      // Apply default sorting
      _sortByCreationDate();

      print('📊 Cleared filters. Items count: ${_items.length}');
    } else {
      _error = 'Failed to clear filters. Status code: ${response.statusCode}';
      print('❌ Error clearing filters: ${response.body}');
      
      // Even if server request fails, clear local filters
      _activeFilters = {};
      _filteredItems = [];
    }
  } catch (e) {
    _error = 'Error occurred while clearing filters: $e';
    print('❌ Error clearing filters: $e');
    
    // Even if an exception occurs, clear local filters
    _activeFilters = {};
    _filteredItems = [];
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}
  
  // Add this method to your DataProvider class
 void applySortWithDirection(String column, bool ascending) {
  print('🔀 Applying sort on column: $column (ascending: $ascending)');
  
  // Store the sort parameters
  _sortColumn = column;
  _sortAscending = ascending;
  _sortingActive = true;
  
  // Store original items if not already stored
  if (_originalItems.isEmpty) {
    _originalItems = List.from(_items);
  }
  
  // Apply the sorting
  _applySorting();
}
  
  // Apply sorting based on column
  void applySort(String column) {
    // If same column, toggle direction
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }

    _applySorting();
  }

  void clearSort() {
  print('🔀 Clearing sort');
  _sortColumn = null;
  _sortAscending = true;
  _sortingActive = false;

  // Restore original items if available
  if (_originalItems.isNotEmpty) {
    _items = List.from(_originalItems);
    
    // Also restore filtered items if needed
    if (_activeFilters.isNotEmpty && _filteredItems.isNotEmpty) {
      // Re-apply filters on original data
      _filteredItems = _items.where((item) {
        // Simple filtering implementation - customize as needed
        return _activeFilters.entries.every((entry) {
          String field = entry.key;
          dynamic filterValue = entry.value;
          String itemValue = item.getStringAttribute(field).toLowerCase();
          
          if (filterValue is String && filterValue.contains(':')) {
            List<String> parts = filterValue.split(':');
            String operator = parts[0];
            String value = parts.sublist(1).join(':').toLowerCase();
            
            switch (operator) {
              case 'equals': return itemValue == value;
              case 'contains': return itemValue.contains(value);
              case 'starts_with': return itemValue.startsWith(value);
              default: return itemValue == value;
            }
          } else if (filterValue != null) {
            return itemValue.contains(filterValue.toString().toLowerCase());
          }
          return true;
        });
      }).toList();
    }
  }
  
  _safeNotifyListeners();
}

  // Apply sorting only (keep separate from filtering now)
  void _applySorting() {
  print('🔀 Executing sort on column: $_sortColumn (ascending: $_sortAscending)');
  
  if (_items.isEmpty) {
    print('⚠️ No items to sort');
    return;
  }
  
  if (_sortColumn == null) {
    print('🔀 No sort column specified, using default sort');
    _sortByCreationDate();
    return;
  }

  // Determine which list to sort
  List<DynamicModel> listToSort = _activeFilters.isNotEmpty ? _filteredItems : _items;
  
  if (listToSort.isEmpty && _activeFilters.isNotEmpty) {
    // If we have filters but no filtered items, nothing to do
    print('⚠️ No filtered items to sort');
    return;
  }
  
  print('🔀 Sorting by column: $_sortColumn');
  
  // Create a copy to sort
  List<DynamicModel> sortedList = List.from(listToSort);
  
  // Debug print some sample values
  if (sortedList.length > 3) {
    print('🔍 Sample values before sort:');
    for (int i = 0; i < 3; i++) {
      print('🔍 Item $i: ${sortedList[i].getStringAttribute(_sortColumn!)}');
    }
  }
  
  // Sort the list
  sortedList.sort((a, b) {
    // Get values from the models
    String valA = a.getStringAttribute(_sortColumn!);
    String valB = b.getStringAttribute(_sortColumn!);
    
    // Check if the values are dates
    bool isDateA = _isDateValue(valA);
    bool isDateB = _isDateValue(valB);
    
    if (isDateA && isDateB) {
      try {
        DateTime dtA = DateTime.parse(valA);
        DateTime dtB = DateTime.parse(valB);
        return _sortAscending ? dtA.compareTo(dtB) : dtB.compareTo(dtA);
      } catch (e) {
        // Fallback to string comparison if date parsing fails
      }
    }
    
    // Try numeric comparison
    try {
      double? numA = double.tryParse(valA);
      double? numB = double.tryParse(valB);
      
      if (numA != null && numB != null) {
        return _sortAscending ? numA.compareTo(numB) : numB.compareTo(numA);
      }
    } catch (e) {}
    
    // Fallback to string comparison
    return _sortAscending ? 
      valA.toLowerCase().compareTo(valB.toLowerCase()) : 
      valB.toLowerCase().compareTo(valA.toLowerCase());
  });
  
  // Update the appropriate list
  if (_activeFilters.isNotEmpty) {
    _filteredItems = sortedList;
  } else {
    _items = sortedList;
  }
  
  // Debug print some sample values after sorting
  if (sortedList.length > 3) {
    print('🔍 Sample values after sort:');
    for (int i = 0; i < 3; i++) {
      print('🔍 Item $i: ${sortedList[i].getStringAttribute(_sortColumn!)}');
    }
  }
  
  print('🔀 Sorting complete. First item value: ${sortedList.isNotEmpty ? sortedList.first.getStringAttribute(_sortColumn!) : "none"}');
  
  // Notify listeners about the change
  _safeNotifyListeners();
}

// Helper method to detect if a string is a date
bool _isDateValue(String value) {
  if (value.isEmpty) return false;
  
  try {
    DateTime.parse(value);
    return true;
  } catch (_) {
    // Try with some common date formats
    final datePatterns = [
      RegExp(r'^\d{4}-\d{2}-\d{2}'),  // YYYY-MM-DD
      RegExp(r'^\d{2}/\d{2}/\d{4}'),  // MM/DD/YYYY
      RegExp(r'^\d{2}\.\d{2}\.\d{4}') // DD.MM.YYYY
    ];
    
    return datePatterns.any((pattern) => pattern.hasMatch(value));
  }
}

  // Get available values for a column - useful for filter dropdowns
  List<String> getUniqueValuesForColumn(String column) {
    final Set<String> uniqueValues = {};

    for (var item in _items) {
      String value = item.getStringAttribute(column);
      if (value.isNotEmpty) {
        uniqueValues.add(value);
      }
    }

    final result = uniqueValues.toList();
    result.sort();
    return result;
  }

  // Rest of the methods (createItem, updateItem) remain unchanged
  Future<Map<String, dynamic>> createItem(String type, Map<String, dynamic> formData, String token) async {
    String endpoint = 'https://qa.api.bussus.com/v2/api/$type';
    _isLoading = true;
    _safeNotifyListeners();

    try {
      print('🌐 Creating new $type with data: ${formData.keys.join(', ')}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'message': _error};
      }

      // IMPORTANT: Properly nest the form data under "data" key
      final requestBody = {
        "data": formData
      };

      print('📦 Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📤 Create response status code: ${response.statusCode}');
      print('📤 Create response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Instead of reloading data, let's fetch just the new item if possible
        try {
          Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData.containsKey('data') && responseData['data'] is Map<String, dynamic>) {
            // Create a new DynamicModel from the response data
            final newItem = DynamicModel.fromJson(responseData['data'], responseData['visible_columns'] ?? []);

            // Add the new item to the beginning of the list
            _items.insert(0, newItem);

            // Re-sort the list to ensure the new item is in the correct position
            _sortByCreationDate();

            // Update filtered items if necessary
            if (_filteredItems.isNotEmpty) {
              _applySorting();
            }

            _safeNotifyListeners();
            return {'success': true};
          }
        } catch (e) {
          print('⚠️ Could not parse response data: $e');
        }

        // Fallback: refresh data if we can't extract the new item
        await loadData(type, token);
        return {'success': true};
      } else {
        Map<String, dynamic> responseData = {};
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          print('❌ Failed to parse error response: $e');
        }

        String errorMsg = responseData['message'] ?? 'Failed to create item. Status code: ${response.statusCode}';
        _error = errorMsg;
        _safeNotifyListeners();
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Error occurred: $e';
      _error = errorMsg;
      print('❌ Error creating data: $e');
      _safeNotifyListeners();
      return {'success': false, 'message': errorMsg};
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateItem(String type, String itemId, Map<String, dynamic> formData, String token) async {
    String endpoint = 'https://qa.api.bussus.com/v2/api/$type/$itemId';
    _isLoading = true;
    _safeNotifyListeners();

    try {
      print('🌐 Updating $type with ID: $itemId');
      print('🌐 Update data: ${formData.keys.join(', ')}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'message': _error};
      }

      // Nest the form data under "data" key
      final requestBody = {
        "data": formData
      };

      print('📦 Request body: ${json.encode(requestBody)}');

      final response = await http.patch(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📤 Update response status code: ${response.statusCode}');
      print('📤 Update response body: ${response.body}');

      if (response.statusCode == 200) {
        // Try to update the item in place if possible
        try {
          Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData.containsKey('data') && responseData['data'] is Map<String, dynamic>) {
            // Find the item in our list
            int itemIndex = _items.indexWhere((item) => item.id == itemId);
            if (itemIndex >= 0) {
              // Update the item in our list
              _items[itemIndex] = DynamicModel.fromJson(responseData['data'], responseData['visible_columns'] ?? []);

              // Re-sort the list to ensure the updated item is in the correct position
              _sortByCreationDate();

              // Update filtered items if necessary
              if (_filteredItems.isNotEmpty) {
                _applySorting();
              }

              _safeNotifyListeners();
              return {'success': true};
            }
          }
        } catch (e) {
          print('⚠️ Could not parse response data: $e');
        }

        // Fallback: refresh data if we can't update the item in place
        await loadData(type, token);
        return {'success': true};
      } else {
        Map<String, dynamic> responseData = {};
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          print('❌ Failed to parse response: $e');
        }

        String errorMsg = responseData['message'] ?? 'Failed to update item. Status code: ${response.statusCode}';
        _error = errorMsg;
        _safeNotifyListeners();
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Error occurred: $e';
      _error = errorMsg;
      print('❌ Error updating data: $e');
      _safeNotifyListeners();
      return {'success': false, 'message': errorMsg};
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<bool> forceRefreshData(String token, String type) async {
    if (_currentListViewId == null) {
      print('Cannot refresh: No list view ID available');
      return false;
    }

    _isLoading = true;
    _safeNotifyListeners(); // Notify loading state

    try {
      // Direct API call to get fresh data
      final response = await http.get(
        Uri.parse('https://qa.api.bussus.com/v2/api/listview/$_currentListViewId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔄 Refresh response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

        // Update all data properties
        _items = apiResponse.data;
        _filteredItems = _items;
        _currentResponse = apiResponse;
        _error = null;

        print('🔄 Forced refresh complete - items: ${_items.length}');
        _isLoading = false;
        _safeNotifyListeners();
        return true;
      } else {
        _error = 'Failed to refresh data. Status code: ${response.statusCode}';
        print('❌ Failed to refresh: ${response.statusCode}');
        _isLoading = false;
        _safeNotifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error refreshing data: $e';
      print('❌ Error refreshing: $e');
      _isLoading = false;
      _safeNotifyListeners();
      return false;
    }
  }

  // Add to data_provider.dart class
Future<Map<String, dynamic>> fetchTaskDetails(String taskId, String token) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();

  try {
    // Check if token exists
    if (token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': _error};
    }

    // Construct the URL for the task details API
    final url = 'https://qa.api.bussus.com/v2/api/task?id=$taskId';

    print('🌐 Fetching task details from: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Response status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      // Handle the response based on whether it's a List or Map
      final dynamic responseData = json.decode(response.body);
      Map<String, dynamic> taskDetails = {};
      
      if (responseData is List && responseData.isNotEmpty) {
        // If the response is directly a List, use the first item
        taskDetails = Map<String, dynamic>.from(responseData[0]);
        print('📊 Loaded task details directly from list response: $taskDetails');
      } else if (responseData is Map) {
        // If the response is a Map with a 'preview' key that is a List
        if (responseData.containsKey('preview') && responseData['preview'] is List && responseData['preview'].isNotEmpty) {
          taskDetails = Map<String, dynamic>.from(responseData['preview'][0]);
          print('📊 Loaded task details from preview in map response: $taskDetails');
        } else {
          // If the response is a Map with direct task details
          taskDetails = Map<String, dynamic>.from(responseData);
          print('📊 Loaded task details directly from map response: $taskDetails');
        }
      } else {
        _error = 'Unexpected response format or empty response.';
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'error': _error};
      }
      
      _isLoading = false;
      _error = null;
      _safeNotifyListeners();
      return {'success': true, 'data': taskDetails};
    } else if (response.statusCode == 401) {
      _error = 'Authentication expired. Please log in again.';
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': _error};
    } else {
      _error = 'Failed to load task details. Status code: ${response.statusCode}';
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': _error};
    }
  } catch (e) {
    _error = 'Error occurred: $e';
    print('❌ Error fetching task details: $e');
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': false, 'error': _error.toString()};
  }
}

// Add to data_provider.dart class
Future<Map<String, dynamic>> deleteTask(String taskId, String token) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();

  try {
    // Check if token exists
    if (token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': _error};
    }

    final url = 'https://qa.api.bussus.com/v2/api/task';
    
    print('🌐 Sending DELETE request to $url with task ID: $taskId');
    
    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "ids": [taskId]
      }),
    );

    print('📤 Delete response status: ${response.statusCode}');
    print('📤 Delete response body: ${response.body}');

    if (response.statusCode == 200) {
      _isLoading = false;
      _error = null;
      _safeNotifyListeners();
      return {'success': true};
    } else {
      String errorMessage;
      try {
        final responseData = json.decode(response.body);
        errorMessage = responseData['message'] ?? 'Failed to delete task';
      } catch (e) {
        errorMessage = 'Failed to delete task. Status code: ${response.statusCode}';
      }

      _error = errorMessage;
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': errorMessage};
    }
  } catch (e) {
    _error = 'Error occurred: $e';
    print('❌ Error deleting task: $e');
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': false, 'error': _error.toString()};
  }
}

Future<Map<String, dynamic>> updateTask(String taskId, Map<String, dynamic> taskData, String token) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();
  try {
    if (token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': _error};
    }
    final url = 'https://qa.api.bussus.com/v2/api/task';
    
    print('🌐 Sending PATCH request to $url with task ID: $taskId');
    print('📝 Task data: $taskData');
    
    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'id': taskId,
        'data': taskData
      }),
    );
    
    print('📤 Update response status: ${response.statusCode}');
    print('📤 Update response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      
      // Check if the response indicates success and has updated records
      if (responseData['success'] == true && 
          responseData['updated_records'] != null && 
          responseData['updated_records'].isNotEmpty) {
        
        // Refresh your task list or task data here
        await refreshTaskList(); // You'll need to implement this method
        
        _isLoading = false;
        _error = null;
        _safeNotifyListeners();
        return {'success': true, 'data': responseData['updated_records'][0]};
      } else {
        // The API returned 200 but no actual updates happened
        _error = 'Update was not applied. Please check your data.';
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'error': _error};
      }
    } else {
      String errorMessage;
      try {
        final responseData = json.decode(response.body);
        errorMessage = responseData['message'] ?? 'Failed to update task';
      } catch (e) {
        errorMessage = 'Failed to update task. Status code: ${response.statusCode}';
      }
      _error = errorMessage;
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': errorMessage};
    }
  } catch (e) {
    _error = 'Error occurred: $e';
    print('❌ Error updating task: $e');
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': false, 'error': _error.toString()};
  }
}

Future<void> refreshTaskList() async {
  // Implement logic to fetch the latest task list from the server
  // This might mean calling your existing fetchTasks() method or similar
  try {
    // Example: await fetchTasks(currentUserToken);
    // You'll need to implement according to your app structure
    print('🔄 Refreshing task list after update');
  } catch (e) {
    print('❌ Error refreshing tasks: $e');
  }
}

  // Add this method to your DataProvider class
Future<Map<String, dynamic>> getFormPreview(String type, String token) async {
  String endpoint = 'https://qa.api.bussus.com/v2/api/$type/preview';
  _isLoading = true;
  _safeNotifyListeners();

  try {
    print('🌐 Fetching form preview for $type');

    // Check if token exists
    if (token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'message': _error};
    }

    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Form preview response status code: ${response.statusCode}');
    
    // Add this detailed logging
    if (response.statusCode == 200) {
      final responseBody = response.body;
      print('📤 Form preview raw response: $responseBody');
      final Map<String, dynamic> responseData = json.decode(responseBody);
      
      // Log specific parts of the response
      if (responseData.containsKey('columns')) {
        print('📊 Columns found in response: ${responseData['columns'].length}');
      } else {
        print('❌ No columns found in response');
      }
      
      if (responseData.containsKey('layout')) {
        print('📋 Layout found in response: ${responseData['layout'].length} sections');
      } else {
        print('❌ No layout found in response');
      }
      
      _isLoading = false;
      _safeNotifyListeners();
      return {
        'success': true, 
        'data': responseData
      };
    } else {
      String errorMsg = 'Failed to fetch form preview. Status code: ${response.statusCode}';
      _error = errorMsg;
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'message': errorMsg};
    }
  } catch (e) {
    String errorMsg = 'Error fetching form preview: $e';
    _error = errorMsg;
    print('❌ Error fetching form preview: $e');
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': false, 'message': errorMsg};
  }
}

// Add this method to get form columns
Future<List<ColumnInfo>> getColumns(String type) async {
  if (_token.isEmpty) {
    print('❌ No token available for getColumns');
    return [];
  }
  
  try {
    final result = await getFormPreview(type, _token);
    print('📊 getColumns result success: ${result['success']}');
    
    if (result['success'] && result['data'] != null) {
      final data = result['data'];
      
      // Check if columns exist in the response
      if (data.containsKey('columns') && data['columns'] is List) {
        List<ColumnInfo> columns = [];
        final columnData = data['columns'] as List<dynamic>;
        
        print('📊 Processing ${columnData.length} columns from API');
        
        for (var column in columnData) {
          columns.add(ColumnInfo(
            name: column['name'] ?? '',
            label: column['label'] ?? '',
            datatype: column['datatype'] ?? 'text',
            required: column['required'] ?? false,
            values: column['values'] ?? '',
          ));
        }
        
        print('📊 Successfully created ${columns.length} column objects');
        return columns;
      } 
      // If no columns but layout exists, create default columns from layout fields
      else if (data.containsKey('layout') && data['layout'] is List) {
        print('📊 No columns found, generating from layout fields');
        List<ColumnInfo> columns = [];
        final layoutData = data['layout'] as List<dynamic>;
        
        // Extract all field names from layout sections
        Set<String> fieldNames = {};
        for (var section in layoutData) {
          if (section is Map<String, dynamic> && section.containsKey('fields')) {
            final fields = section['fields'] as List;
            fieldNames.addAll(fields.cast<String>());
          }
        }
        
        print('📊 Creating ${fieldNames.length} columns from layout fields');
        
        // Create default ColumnInfo objects for each field
        for (String fieldName in fieldNames) {
          // Convert field name to label (e.g., "email_address" -> "Email Address")
          String label = fieldName.replaceAll('_', ' ')
              .split(' ')
              .map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
              .join(' ');
          
          // Guess datatype based on field name
          String datatype = 'text';
          if (fieldName.contains('email')) {
            datatype = 'email';
          } else if (fieldName.contains('phone')) datatype = 'phone';
          else if (fieldName.contains('date')) datatype = 'date';
          else if (fieldName.contains('price') || fieldName.contains('amount')) datatype = 'number';
          
          // Guess if field is required (common required fields)
          bool required = ['name', 'email', 'phone', 'status'].contains(fieldName);
          
          // Guess dropdown values for common fields
          String values = '';
          if (fieldName == 'status') {
            values = 'New,In Progress,Completed,Cancelled';
          }
          
          columns.add(ColumnInfo(
            name: fieldName,
            label: label,
            datatype: datatype,
            required: required,
            values: values,
          ));
        }
        
        print('📊 Successfully created ${columns.length} default column objects');
        return columns;
      } else {
        print('❌ No columns or layout key in API response data');
      }
    } else {
      print('❌ API call unsuccessful or empty data');
    }
    return [];
  } catch (e) {
    print('❌ Error parsing columns: $e');
    return [];
  }
}

Future<List<FormSection>> getFormLayout(String type) async {
  if (_token.isEmpty) {
    print('❌ No token available for getFormLayout');
    return [];
  }
  
  try {
    final result = await getFormPreview(type, _token);
    print('📋 getFormLayout result success: ${result['success']}');
    
    if (result['success'] && result['data'] != null) {
      final data = result['data'];
      if (data.containsKey('layout') && data['layout'] is List) {
        List<FormSection> sections = [];
        final layoutData = data['layout'] as List<dynamic>;
        
        print('📋 Processing ${layoutData.length} layout sections from API');
        
        for (var section in layoutData) {
          if (section is Map<String, dynamic> && 
              section.containsKey('title') && 
              section.containsKey('fields')) {
            sections.add(FormSection(
              title: section['title'],
              fields: List<String>.from(section['fields']),
            ));
          }
        }
        
        print('📋 Successfully created ${sections.length} form sections');
        return sections;
      } else {
        print('❌ No layout key or not a list in API response data');
      }
    } else {
      print('❌ API call unsuccessful or empty data for form layout');
    }
    return [];
  } catch (e) {
    print('❌ Error parsing form layout: $e');
    return [];
  }
}

// Add this method to your DataProvider class in data_provider.dart

Future<Map<String, dynamic>> fetchItemPreview(String type, String itemId, String token) async {
  try {
    final url = 'https://qa.api.bussus.com/v2/api/$type/preview?id=$itemId';
    
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
      return responseData;
    } else {
      print('❌ Failed to fetch item preview: ${response.statusCode}');
      print('Response: ${response.body}');
      throw Exception('Failed to fetch item preview: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching item preview: $e');
    throw Exception('Error fetching item preview: $e');
  }
}
// Add these new methods to your existing DataProvider class

Future<Map<String, dynamic>> fetchItemDetails(String type, String itemId) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();

  Map<String, dynamic> result = {
    'data': {},
    'all_columns': [],
    'visible_columns': [],
    'layout': {'sections': []},
    'tasks': [],
  };

  try {
    if (_token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return result;
    }

    // Construct the URL for the details API
    final url = 'https://qa.api.bussus.com/v2/api/$type/preview?id=$itemId';
    print('🌐 Fetching details from: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Details response status code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      result = json.decode(response.body);
      _error = null;
      print('📄 Successfully fetched item details');
    } else if (response.statusCode == 401) {
      _error = 'Authentication expired. Please log in again.';
      print('⚠️ Authentication expired');
    } else {
      _error = 'Failed to load details. Status code: ${response.statusCode}';
      print('❌ Failed to load details: ${response.body}');
    }
  } catch (e) {
    _error = 'Error occurred: $e';
    print('❌ Error fetching details: $e');
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
  
  return result;
}

Future<bool> deleteItem(String type, String itemId) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();
  
  try {
    if (_token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return false;
    }
    
    final url = 'https://qa.api.bussus.com/v2/api/$type';
    
    print('🗑️ Attempting to delete item from: $url');
    print('🗑️ Item ID to delete: $itemId');
    
    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "ids": [itemId]
      }),
    );
    
    print('📤 Delete response status code: ${response.statusCode}');
    print('📤 Delete response body: ${response.body}');
    
    if (response.statusCode == 200) {
      _error = null;
      print('✅ Item deleted successfully');
      
      // Remove the deleted item from our local lists
      _items.removeWhere((item) => item.id == itemId);
      _filteredItems.removeWhere((item) => item.id == itemId);
      if (_originalItems.isNotEmpty) {
        _originalItems.removeWhere((item) => item.id == itemId);
      }
      
      _safeNotifyListeners();
      return true;
    } else {
      try {
        final responseData = json.decode(response.body);
        _error = responseData['message'] ?? 'Failed to delete item';
      } catch (e) {
        _error = 'Failed to delete item. Status code: ${response.statusCode}';
      }
      
      print('❌ Failed to delete item: $_error');
      _safeNotifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error deleting item: $e';
    print('❌ Error deleting item: $e');
    _safeNotifyListeners();
    return false;
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData, String token, String type) async {
    // Determine the correct endpoint based on the object type
    String endpoint = 'https://qa.api.bussus.com/v2/api/$type/task';
    _isLoading = true;
    _safeNotifyListeners();

    try {
      print('🌐 Creating new task for $type with data: ${taskData.keys.join(', ')}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'message': _error};
      }

      // Nest the task data under "data" key
      final requestBody = {
        "data": taskData
      };

      print('📦 Request body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('📤 Create task response status code: ${response.statusCode}');
      print('📤 Create task response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData['data']
        };
      } else {
        Map<String, dynamic> responseData = {};
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          print('❌ Failed to parse error response: $e');
        }

        String errorMsg = responseData['message'] ?? 'Failed to create task. Status code: ${response.statusCode}';
        _error = errorMsg;
        _safeNotifyListeners();
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Error occurred: $e';
      _error = errorMsg;
      print('❌ Error creating task: $e');
      _safeNotifyListeners();
      return {'success': false, 'message': errorMsg};
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // Add these methods to your DataProvider class

/// Fetch user information by name
Future<Map<String, dynamic>?> getUserByName(String name, String token) async {
  _isLoading = true;
  _safeNotifyListeners();

  try {
    print('🔍 Looking up user by name: $name');

    if (token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return null;
    }

    // Endpoint to get user by name
    final endpoint = 'https://qa.api.bussus.com/v2/api/users/search?name=$name';

    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Get user response status code: ${response.statusCode}');
    print('📤 Get user response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      // Check if any users were found
      if (responseData['data'] != null && responseData['data'].isNotEmpty) {
        // Return the first user that matches the name
        return responseData['data'][0];
      } else {
        print('⚠️ No users found with name: $name');
        return null;
      }
    } else {
      Map<String, dynamic> responseData = {};
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        print('❌ Failed to parse error response: $e');
      }

      String errorMsg = responseData['message'] ?? 'Failed to find user. Status code: ${response.statusCode}';
      _error = errorMsg;
      _safeNotifyListeners();
      return null;
    }
  } catch (e) {
    String errorMsg = 'Error looking up user: $e';
    _error = errorMsg;
    print('❌ Error getting user: $e');
    _safeNotifyListeners();
    return null;
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}

/// Get the owner ID of a related object
Future<int?> getRelatedObjectOwnerId(String objectId, String objectType, String token) async {
  _isLoading = true;
  _safeNotifyListeners();

  try {
    print('🔍 Getting owner ID for $objectType with ID: $objectId');

    if (token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return null;
    }

    // Endpoint to get object details
    final endpoint = 'https://qa.api.bussus.com/v2/api/$objectType/$objectId';

    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Get object response status code: ${response.statusCode}');
    print('📤 Get object response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      // Look for owner_id or user_id in the response
      if (responseData['data'] != null) {
        var data = responseData['data'];
        // Try to find owner ID in various possible field names
        int? ownerId = data['owner_id'] ?? data['user_id'] ?? data['created_by'];
        
        if (ownerId == null) {
          print('⚠️ No owner ID found for $objectType with ID: $objectId');
        } else {
          print('✅ Found owner ID: $ownerId');
        }
        
        return ownerId;
      } else {
        print('⚠️ No data field in response for $objectType with ID: $objectId');
        return null;
      }
    } else {
      Map<String, dynamic> responseData = {};
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        print('❌ Failed to parse error response: $e');
      }

      String errorMsg = responseData['message'] ?? 'Failed to get object details. Status code: ${response.statusCode}';
      _error = errorMsg;
      _safeNotifyListeners();
      return null;
    }
  } catch (e) {
    String errorMsg = 'Error getting object details: $e';
    _error = errorMsg;
    print('❌ Error getting object details: $e');
    _safeNotifyListeners();
    return null;
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}
  // Add this to your DataProvider class

  Future<void> searchData(String type, String query, String token) async {
    _isLoading = true;
    _error = null;
    _safeNotifyListeners();

    try {
      // Construct the URL with search parameter
      final url = Uri.parse('https://qa.api.bussus.com/v2/api/listview/$type?listview=all&search=$query&limit=10&offset=0');

      print('🔍 Searching $type with query: "$query"');
      print('🌐 Search URL: ${url.toString()}');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📤 Search response status code: ${response.statusCode}');
      print('📤 Search response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

        // Store the results in _items and _filteredItems
        _items = apiResponse.data;
        _filteredItems = _items;
        _currentResponse = apiResponse;
        _currentListViewId = apiResponse.listview.id;
        _error = null;

        print('🔍 Found ${_items.length} search results for "$query"');
      } else if (response.statusCode == 401) {
        _error = 'Authentication expired. Please log in again.';
        _items = [];
        _filteredItems = [];
      } else if (response.statusCode == 404) {
        _error = 'No results found.';
        _items = [];
        _filteredItems = [];
      } else {
        _error = 'Search failed. Status code: ${response.statusCode}';
        _items = [];
        _filteredItems = [];
      }
    } catch (e) {
      _error = 'Error occurred during search: $e';
      _items = [];
      _filteredItems = [];
      print('❌ Error during search: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

}