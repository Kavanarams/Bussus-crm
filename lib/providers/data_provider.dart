import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dynamic_model.dart';

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
    print('🔑 Using token: ${token.isNotEmpty ? token.substring(0, 10) + '...' : 'Empty token'}');
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
      print('📊 ListView ID: ${_currentListViewId}');
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
        endpoint = endpoint + '&limit=1000'; // Add high limit
      } else {
        endpoint = endpoint + '?limit=1000'; // Add high limit
      }
      print('🌐 Fetching data from: $endpoint');
      print('🔑 Using token: ${token.isNotEmpty ? token.substring(0, 10) + '...' : 'Empty token'}');

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
        print('📊 ListView ID: ${_currentListViewId}');
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
        Uri.parse('https://qa.api.bussus.com/v2/api/listview/${_currentListViewId}'),
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