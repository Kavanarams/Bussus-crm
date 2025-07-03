import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/dynamic_model.dart';
import '../config/api_config.dart';
 
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
  String? lastError;
  String _activeType = '';

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

  bool isServingType(String type) {
  return _activeType == type;
}

// Get current active type
String get activeType => _activeType;
  void setSortingActive(bool value) {
    _sortingActive = value;
    if (value) {
      // When activating sorting, store the original items
      _originalItems = List.from(_items);
    }
    _safeNotifyListeners();
  }

  // FIX: Updated getter to correctly handle filtered vs unfiltered state
  // List<DynamicModel> get items {
  //   // If filter is active but filteredItems is empty, show loading or empty state
  //   if (_activeFilters.isNotEmpty) {
  //     return _filteredItems;
  //   } else {
  //     return _items;
  //   }
  // }

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
  Map<String, dynamic> get activeFilters => Map.from(_activeFilters);
  String? get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;
  // ADD: Method to check if filters are currently active
  bool get hasActiveFilters => _activeFilters.isNotEmpty;
  // ADD: Method to get filter count
  int get activeFilterCount => _activeFilters.length;

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

  // Helper method to ensure type is in plural form
 String _getCorrectType(String type) {
  // Only these specific types should be plural
  switch (type.toLowerCase()) {
    case 'lead':
      return 'leads';
    case 'account':
      return 'accounts';
    default:
      // All other types remain singular
      return type;
  }
}

void resetForNewType(String newType) {
  print('🔄 Resetting DataProvider for new type: $newType');
  
  // Only reset if we're actually changing types
  if (_activeType == newType) {
    print('ℹ️ Same type, preserving filters and state');
    return; // Don't reset if it's the same type
  }
  
  // Clear all data
  _items = [];
  _filteredItems = [];
  _originalItems = [];
  
  // Reset state
  _currentResponse = null;
  _currentListViewId = null;
  _error = null;
  
  // Reset filters and sorting ONLY when changing types
  _activeFilters = {};
  _sortColumn = null;
  _sortAscending = true;
  _sortingActive = false;
  
  // Update type
  _type = newType;
  _activeType = newType;
  
  _safeNotifyListeners();
}
  // Updated to require token as a parameter and handle plural type
  Future<void> loadData(String type, String token) async {
  print('🔍 LoadData called for type: $type, current active type: $_activeType');
  
  if (_isLoading && _activeType == type) {
    print('⚠️ Already loading data for $type, ignoring duplicate request');
    return;
  }
  
  if (_isLoading && _activeType != type) {
    print('🔄 Switching from $_activeType to $type while loading');
  }
  
  bool switchingTypes = _activeType != type;
  _activeType = type;
  _token = token;
  _type = type;
  
  // IMPORTANT: Only reset filters if switching types
  if (switchingTypes) {
    print('🔄 Switching types, clearing all state');
    _items = [];
    _filteredItems = [];
    _originalItems = [];
    _currentResponse = null;
    _currentListViewId = null;
    _error = null;
    _activeFilters = {}; // Only clear filters when switching types
    _sortColumn = null;
    _sortAscending = true;
    _sortingActive = false;
  } else {
    print('ℹ️ Same type, preserving filters: $_activeFilters');
    // For same type, only clear data but preserve filters
    if (_activeFilters.isEmpty) {
      _items = [];
      _filteredItems = [];
      _originalItems = [];
    }
  }
  
  _isLoading = true;
  _safeNotifyListeners();

  try {
    String correctType = _getCorrectType(type);
    String endpoint = '${ApiConfig.baseUrl.replaceFirst('qa', 'dev')}/api/listview/$correctType?limit=1000';
    
    print('🌐 Fetching data from: $endpoint for type: $type');

    if (token.isEmpty) {
      if (_activeType == type) {
        _error = 'Authentication required. Please log in.';
        _isLoading = false;
        _safeNotifyListeners();
      }
      return;
    }

    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Response status code: ${response.statusCode} for type: $type');

    if (_activeType != type) {
      print('⚠️ Type changed during request, ignoring response for $type');
      return;
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      try {
        final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

        if (_activeType == type) {
          _currentListViewId = apiResponse.listview.id;
          _currentResponse = apiResponse;
          
          // CRITICAL: Check if we have active filters
          if (_activeFilters.isNotEmpty) {
            print('🔍 Active filters detected, re-applying filters to maintain filtered state');
            // Don't update _items with unfiltered data, keep current filtered state
            // The UI should show the filtered data, not the fresh unfiltered data
            _error = null;
            print('📊 Preserved filtered state with ${_filteredItems.length} filtered items');
            print('📊 Active filters maintained: $_activeFilters');
            
            // Re-apply the filters to ensure server state matches
            Map<String, String> filterMap = {};
            _activeFilters.forEach((field, value) {
              filterMap[field] = value.toString();
            });
            
            // Re-apply filters without changing the UI state
            _reapplyFiltersInBackground(filterMap, token, type);
            
          } else {
            // No filters are active, load all data normally
            _items = apiResponse.data;
            _filteredItems = [];
            _originalItems = List.from(_items);
            
            if (_sortColumn == null) {
              _sortByCreationDate();
            }
            print('📊 Successfully loaded ${_items.length} items for $correctType (type: $type)');
          }
          
          _error = null;
          print('📊 Active filters: $_activeFilters');
        }
        
      } catch (parseError) {
        if (_activeType == type) {
          _error = 'Error parsing data: $parseError';
          print('❌ Parse error for $type: $parseError');
          if (_activeFilters.isEmpty) {
            _items = [];
            _filteredItems = [];
          }
        }
      }
    } else if (response.statusCode == 401) {
      if (_activeType == type) {
        _error = 'Authentication expired. Please log in again.';
      }
    } else if (response.statusCode == 404) {
      if (_activeType == type) {
        _error = 'No data found for this view.';
      }
    } else {
      if (_activeType == type) {
        _error = 'Failed to load data. Status code: ${response.statusCode}';
      }
    }
  } catch (e) {
    if (_activeType == type) {
      _error = 'Error occurred: $e';
      print('❌ Error fetching data for $type: $e');
    }
  } finally {
    if (_activeType == type) {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }
}

Future<void> _reapplyFiltersInBackground(Map<String, String> filters, String token, String type) async {
  try {
    if (_currentListViewId == null) {
      print('⚠️ No list view ID available for re-applying filters');
      return;
    }

    // Build the filters array in the required format
    List<Map<String, String>> filtersList = [];
    filters.forEach((field, value) {
      if (value.isNotEmpty) {
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
          filtersList.add({
            'field': field,
            'operator': 'equals',
            'value': value
          });
        }
      }
    });

    final Map<String, dynamic> payload = {
      'data': {
        'filters': filtersList,
        'filter_logic': '',
        'id': _currentListViewId
      }
    };

    print('🔍 Re-applying filters in background: ${json.encode(payload)}');

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl.replaceFirst('qa', 'dev')}/api/listview'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

      // Update the filtered items
      _filteredItems = apiResponse.data;
      _items = _filteredItems;
      _currentResponse = apiResponse;

      print('📊 Background filter re-application successful. Items: ${_filteredItems.length}');
      _safeNotifyListeners();
    } else {
      print('❌ Background filter re-application failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error in background filter re-application: $e');
  }
}
// Updated applyFilters method - now fetches data after applying filter
Future<void> applyFilters(Map<String, String> filters, String token, String type) async {
  print('🔍 Applying filters: $filters');
  
  _isLoading = true;
  _activeFilters = Map<String, dynamic>.from(filters);
  _safeNotifyListeners();

  try {
    if (_currentListViewId == null) {
      throw Exception('No list view ID available for filtering');
    }

    // Build filters array
    List<Map<String, String>> filtersList = [];
    filters.forEach((field, value) {
      if (value.isNotEmpty) {
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
          filtersList.add({
            'field': field,
            'operator': 'equals',
            'value': value
          });
        }
      }
    });

    final payload = {
      'data': {
        'filters': filtersList,
        'filter_logic': '',
        'id': _currentListViewId
      }
    };

    print('🔍 Filter payload: ${json.encode(payload)}');

    // Step 1: Apply the filter to the list view
    final filterResponse = await http.patch(
      Uri.parse('${ApiConfig.baseUrl.replaceFirst('qa', 'dev')}/api/listview'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (filterResponse.statusCode != 200) {
      throw Exception('Filter application failed: ${filterResponse.statusCode}');
    }

    print('✅ Filter applied to list view successfully');

    // Step 2: Fetch the filtered data
    await _fetchFilteredData(token, type);

  } catch (e) {
    _error = 'Error applying filters: $e';
    print('❌ Filter error: $e');
    // Reset filtered items on error
    _filteredItems = [];
    _activeFilters = {};
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}

// New method to fetch filtered data
Future<void> _fetchFilteredData(String token, String type) async {
  try {
    print('📡 Fetching filtered data for type: $type');
    
    // Use the same endpoint as loadData but it should now return filtered results
    // since we just applied the filter to the list view
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl.replaceFirst('qa', 'dev')}/api/$type/listview'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic responseData = json.decode(response.body);
      
      print('📡 Response type: ${responseData.runtimeType}');
      print('📡 Response data: ${responseData.toString().substring(0, responseData.toString().length > 200 ? 200 : responseData.toString().length)}...');
      
      // Handle different response formats
      if (responseData is List<dynamic>) {
        // Direct array response - convert to DynamicModel list
        _filteredItems = responseData.map((item) => DynamicModel.fromJson(
          item as Map<String, dynamic>, 
          []
        )).toList().cast<DynamicModel>();
        print('📊 Direct array response - Filtered data fetched successfully. Items: ${_filteredItems.length}');
      } else if (responseData is Map<String, dynamic>) {
        // Wrapped response
        final ApiResponse apiResponse = ApiResponse.fromJson(responseData);
        _filteredItems = apiResponse.data.map((item) => DynamicModel.fromJson(
          item as Map<String, dynamic>, 
          []
        )).toList().cast<DynamicModel>();
        _currentResponse = apiResponse;
        print('📊 Wrapped response - Filtered data fetched successfully. Items: ${_filteredItems.length}');
      } else {
        throw Exception('Unexpected response format: ${responseData.runtimeType}');
      }

      _error = null;

      // Re-apply sorting if it was active
      if (_sortingActive && _sortColumn != null) {
        _applySortingToFilteredData();
      }
      
      // Debug: Log some sample filtered data
      if (_filteredItems.isNotEmpty) {
        final firstItem = _filteredItems.first;
        // Access the raw JSON data from the first item
        final itemData = (responseData is List<dynamic>) 
          ? responseData.first as Map<String, dynamic>
          : (responseData as Map<String, dynamic>)['data'][0] as Map<String, dynamic>;
        print('📊 Sample filtered item keys: ${itemData.keys}');
        // Try to find name field in the first item
        if (itemData.containsKey('name')) {
          print('📊 First item name: ${itemData['name']}');
        }
      } else {
        print('📊 No items match the current filter criteria');
      }
      
    } else {
      print('❌ HTTP Error: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      throw Exception('Failed to fetch filtered data: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching filtered data: $e');
    throw e; // Re-throw to be handled by the calling method
  }
}

// Updated clearFilters method
Future<void> clearFilters() async {
  print('🔍 Clearing all filters');
  
  _isLoading = true;
  _safeNotifyListeners();

  try {
    if (_currentListViewId == null) {
      throw Exception('No list view ID available');
    }

    final payload = {
      'data': {
        'filters': [],
        'filter_logic': '',
        'id': _currentListViewId
      }
    };

    // Step 1: Clear filters on the server
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl.replaceFirst('qa', 'dev')}/api/listview'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Clear filters failed: ${response.statusCode}');
    }

    print('✅ Filters cleared on server');

    // Step 2: Fetch all data (now unfiltered)
    await _fetchAllData(_token, _type);
    
    // Step 3: Clear local filter state
    _activeFilters = {};
    _filteredItems = [];
    
    print('📊 Filters cleared. Items restored: ${_items.length}');
    
  } catch (e) {
    // Clear local state even if server request fails
    _activeFilters = {};
    _filteredItems = [];
    _error = 'Error clearing filters: $e';
    print('❌ Clear filters error: $e');
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}

// Helper method to fetch all data (used by clearFilters)
Future<void> _fetchAllData(String token, String type) async {
  try {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl.replaceFirst('qa', 'dev')}/api/$type/listview'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic responseData = json.decode(response.body);
      
      // Handle different response formats
      if (responseData is List<dynamic>) {
        // Direct array response - convert to DynamicModel list
        _items = responseData.map((item) => DynamicModel.fromJson(
          item as Map<String, dynamic>, 
          []
        )).toList().cast<DynamicModel>();
        _originalItems = responseData.map((item) => DynamicModel.fromJson(
          item as Map<String, dynamic>, 
          []
        )).toList().cast<DynamicModel>();
        print('📊 Direct array response - All data fetched successfully. Items: ${_items.length}');
      } else if (responseData is Map<String, dynamic>) {
        // Wrapped response
        final ApiResponse apiResponse = ApiResponse.fromJson(responseData);
        _items = apiResponse.data.map((item) => DynamicModel.fromJson(
          item as Map<String, dynamic>, 
          []
        )).toList().cast<DynamicModel>();
        _originalItems = apiResponse.data.map((item) => DynamicModel.fromJson(
          item as Map<String, dynamic>, 
          []
        )).toList().cast<DynamicModel>();
        _currentResponse = apiResponse;
        print('📊 Wrapped response - All data fetched successfully. Items: ${_items.length}');
      } else {
        throw Exception('Unexpected response format: ${responseData.runtimeType}');
      }

      _error = null;

      // Re-apply default sorting
      _sortByCreationDate();
      
    } else {
      throw Exception('Failed to fetch all data: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching all data: $e');
    throw e;
  }
}

// Keep the same items getter as before
List<DynamicModel> get items {
  // Return filtered items if filters are active, otherwise return all items
  if (_activeFilters.isNotEmpty && _filteredItems.isNotEmpty) {
    return _filteredItems;
  } else if (_activeFilters.isNotEmpty && _filteredItems.isEmpty) {
    // If filters are active but no results, return empty list
    return <DynamicModel>[];
  } else {
    // No filters active, return all items
    return _items;
  }
}


List<DynamicModel> getItemsForType(String type) {
  if (_activeType != type) {
    print('⚠️ Requested items for $type but provider is serving $_activeType');
    return [];
  }
  
  if (_activeFilters.isNotEmpty) {
    return _filteredItems;
  } else {
    return _items;
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
      // Make sure we're using dev instead of qa
      endpoint = endpoint.replaceFirst('qa.api.bussus.com', 'dev.api.bussus.com');
      
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
  
  
  
  // Add this method to your DataProvider class
  void applySortWithDirection(String column, bool ascending) {
  print('🔀 Applying sort: $column (ascending: $ascending)');
  
  _sortColumn = column;
  _sortAscending = ascending;
  _sortingActive = true;
  
  // Apply sorting to current data (filtered or unfiltered)
  if (_activeFilters.isNotEmpty && _filteredItems.isNotEmpty) {
    _applySortingToFilteredData();
  } else {
    _applySortingToAllData();
  }
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
  
  // Restore data without sorting
  if (_activeFilters.isNotEmpty) {
    // If filters are active, we need to re-apply them without sorting
    // For now, just notify listeners - the filtered data remains
    print('🔀 Sort cleared but filters remain active');
  } else {
    // Restore original order
    if (_originalItems.isNotEmpty) {
      _items = List.from(_originalItems);
      _sortByCreationDate(); // Apply default sort
    }
  }
  
  _safeNotifyListeners();
}

void _applySortingToAllData() {
  if (_items.isEmpty || _sortColumn == null) return;
  
  List<DynamicModel> sortedItems = List.from(_items);
  _performSort(sortedItems);
  _items = sortedItems;
  _safeNotifyListeners();
}

void _applySortingToFilteredData() {
  if (_filteredItems.isEmpty || _sortColumn == null) return;
  
  List<DynamicModel> sortedItems = List.from(_filteredItems);
  _performSort(sortedItems);
  _filteredItems = sortedItems;
  _safeNotifyListeners();
}

void _performSort(List<DynamicModel> items) {
  if (_sortColumn == null) return;
  
  items.sort((a, b) {
    String valA = a.getStringAttribute(_sortColumn!);
    String valB = b.getStringAttribute(_sortColumn!);
    
    // Handle empty values
    if (valA.isEmpty && valB.isEmpty) return 0;
    if (valA.isEmpty) return _sortAscending ? 1 : -1;
    if (valB.isEmpty) return _sortAscending ? -1 : 1;
    
    // Try date comparison first
    if (_isDateValue(valA) && _isDateValue(valB)) {
      try {
        DateTime dtA = DateTime.parse(valA);
        DateTime dtB = DateTime.parse(valB);
        return _sortAscending ? dtA.compareTo(dtB) : dtB.compareTo(dtA);
      } catch (e) {
        // Fall through to string comparison
      }
    }
    
    // Try numeric comparison
    double? numA = double.tryParse(valA);
    double? numB = double.tryParse(valB);
    
    if (numA != null && numB != null) {
      return _sortAscending ? numA.compareTo(numB) : numB.compareTo(numA);
    }
    
    // String comparison
    return _sortAscending ? 
      valA.toLowerCase().compareTo(valB.toLowerCase()) : 
      valB.toLowerCase().compareTo(valA.toLowerCase());
  });
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
  
  // Helper method to check if a string is likely a date
  bool _isDateValue(String value) {
    if (value.isEmpty) return false;
    
    // Check common date formats
    try {
      DateTime.parse(value);
      return true;
    } catch (_) {
      // Try some common date formats
      final datePatterns = [
        RegExp(r'^\d{4}-\d{2}-\d{2}'),               // YYYY-MM-DD
        RegExp(r'^\d{2}/\d{2}/\d{4}'),               // MM/DD/YYYY
        RegExp(r'^\d{2}-\d{2}-\d{4}'),               // DD-MM-YYYY
        RegExp(r'^\d{4}/\d{2}/\d{2}'),               // YYYY/MM/DD
        RegExp(r'^\d{2} [A-Za-z]{3} \d{4}'),         // DD MMM YYYY
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
  
 Future<Map<String, dynamic>> updateItem(String type, String itemId, Map<String, dynamic> formData, String token) async {
  // Ensure type is in plural form
  final correctType = _getCorrectType(type);
  
  // Use ApiConfig for base URL
  String endpoint = '${ApiConfig.baseUrl}/api/$correctType/$itemId';
  
  _isLoading = true;
  _safeNotifyListeners();

  try {
    print('🌐 Updating $correctType with ID: $itemId');
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
      // Parse the response
      Map<String, dynamic> responseData = json.decode(response.body);
      
      // **FIX: Check for errors first - even when success is true**
      if (responseData.containsKey('errors') && 
          responseData['errors'] is List && 
          responseData['errors'].isNotEmpty) {
        
        // Handle errors from the response
        var errorList = responseData['errors'] as List;
        String errorMsg = '';
        
        for (var error in errorList) {
          if (error is Map<String, dynamic>) {
            String errorDetail = error['error'] ?? 'Unknown error';
            print('❌ Database error: $errorDetail');
            
            // Extract user-friendly error message
            if (errorDetail.contains('foreign key constraint')) {
              if (errorDetail.contains('converted_account_id_fkey')) {
                errorMsg = 'The selected account "${formData['converted_account_id']}" does not exist. Please choose a valid account.';
              } else if (errorDetail.contains('created_by_id_fkey')) {
                errorMsg = 'The user "${formData['created_by_id']}" does not exist in the system.';
              } else if (errorDetail.contains('owner_id_fkey')) {
                errorMsg = 'The selected owner does not exist. Please choose a valid owner.';
              } else if (errorDetail.contains('partner_account_id_fkey')) {
                errorMsg = 'The selected partner account does not exist.';
              } else {
                errorMsg = 'Invalid reference data. Please check your selections.';
              }
            } else {
              errorMsg = errorDetail;
            }
            break; // Use first error
          }
        }
        
        _error = errorMsg;
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'message': errorMsg};
      }
      
      // Check if we have updated_records in the response
      if (responseData.containsKey('updated_records') && 
          responseData['updated_records'] is List && 
          responseData['updated_records'].isNotEmpty) {
        
        var updatedRecord = responseData['updated_records'][0];
        var updatedData = updatedRecord['updated_data'];
        
        print('📝 Processing updated record with data: ${updatedData.keys.join(', ')}');
        
        // Update the item in all lists
        _updateItemInLists(itemId, updatedData);
        
        print('📝 Item update completed successfully');
        _error = null;
        _safeNotifyListeners();
        return {'success': true};
        
      } else if (responseData.containsKey('success') && responseData['success'] == true) {
        // **FIX: Handle case where success is true but no updated_records**
        // This means the update was successful, update UI with form data
        _updateItemInLists(itemId, formData);
        
        print('📝 Updated item using form data (success without updated_records)');
        _error = null;
        _safeNotifyListeners();
        return {'success': true};
        
      } else if (responseData.containsKey('data')) {
        // Fallback for different response format
        print('📝 Using fallback response format');
        _updateItemInLists(itemId, responseData['data']);
        _error = null;
        _safeNotifyListeners();
        return {'success': true};
        
      } else {
        // If we can't parse the response properly, reload the data
        print('⚠️ Could not parse update response, reloading data...');
        await loadData(type, token);
        return {'success': true};
      }
    } else {
      Map<String, dynamic> responseData = {};
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        print('❌ Failed to parse error response: $e');
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

// **NEW: Helper method to update item in all lists**
void _updateItemInLists(String itemId, Map<String, dynamic> updatedData) {
  // Update main items list
  int itemIndex = _items.indexWhere((item) => item.id == itemId);
  if (itemIndex >= 0) {
    print('📝 Found item at index $itemIndex, updating...');
    
    var existingItem = _items[itemIndex];
    var newItemData = Map<String, dynamic>.from(existingItem.attributes);
    
    // Update with new data
    updatedData.forEach((key, value) {
      newItemData[key] = value;
    });
    
    // Ensure ID is preserved
    newItemData['id'] = itemId;
    
    // Create new DynamicModel
    _items[itemIndex] = DynamicModel.fromJson(newItemData, visibleColumns);
    print('📝 Updated item in main list successfully');
  }
  
  // Update filtered items
  if (_activeFilters.isNotEmpty && _filteredItems.isNotEmpty) {
    int filteredIndex = _filteredItems.indexWhere((item) => item.id == itemId);
    if (filteredIndex >= 0) {
      var existingFilteredItem = _filteredItems[filteredIndex];
      var newFilteredItemData = Map<String, dynamic>.from(existingFilteredItem.attributes);
      
      updatedData.forEach((key, value) {
        newFilteredItemData[key] = value;
      });
      newFilteredItemData['id'] = itemId;
      
      _filteredItems[filteredIndex] = DynamicModel.fromJson(newFilteredItemData, visibleColumns);
      print('📝 Updated item in filtered list successfully');
    }
  }
  
  // Update original items
  if (_originalItems.isNotEmpty) {
    int originalIndex = _originalItems.indexWhere((item) => item.id == itemId);
    if (originalIndex >= 0) {
      var existingOriginalItem = _originalItems[originalIndex];
      var newOriginalItemData = Map<String, dynamic>.from(existingOriginalItem.attributes);
      
      updatedData.forEach((key, value) {
        newOriginalItemData[key] = value;
      });
      newOriginalItemData['id'] = itemId;
      
      _originalItems[originalIndex] = DynamicModel.fromJson(newOriginalItemData, visibleColumns);
      print('📝 Updated item in original list successfully');
    }
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
    final url = 'https://dev.api.bussus.com/v2/api/task?id=$taskId';

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

  // Add this method to your DataProvider class
Future<Map<String, dynamic>> getFormPreview(String type, String token) async {
  // Apply plural form to resource type
  String correctType = _getCorrectType(type);
  
  // Use ApiConfig.baseUrl instead of hardcoded URL
  String endpoint = '${ApiConfig.baseUrl}/api/$correctType/preview';
  _isLoading = true;
  _safeNotifyListeners();

  try {
    print('🌐 Fetching form preview for $type from: $endpoint');

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
          } else if (fieldName == 'rating') {
            values = 'hot,warm,cold';
          }
          
          columns.add(ColumnInfo(
            name: fieldName,
            label: label,
            datatype: datatype,
            required: required,
            values: [],
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

Future<Map<String, dynamic>> createItem(String type, Map<String, dynamic> formData, String token) async {
  // Apply plural form to resource type
  String correctType = _getCorrectType(type);
  
  // Use ApiConfig.baseUrl instead of hardcoded URL
  String endpoint = '${ApiConfig.baseUrl}/api/$correctType';
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

// Add this method to your DataProvider class in data_provider.dart
Future<Map<String, dynamic>> fetchItemPreview(String type, String itemId, String token) async {
  try {
    final correctType = _getCorrectType(type);
    final url = '${ApiConfig.baseUrl}/api/$correctType/preview?id=$itemId';
    
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
// Add this method to your DataProvider class:

Future<Map<String, dynamic>> fetchItemDetails(String type, String itemId) async {
  try {
    // Ensure type is in correct format
    final correctType = _getCorrectType(type);
    
    // Use dev endpoint instead of qa
    String endpoint = '${ApiConfig.baseUrl.replaceFirst('qa', 'dev')}/api/$correctType/preview?id=$itemId';
    
    print('🌐 Fetching details from: $endpoint');

    if (_token.isEmpty) {
      throw Exception('Authentication required. Please log in.');
    }

    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
    );

    print('📤 Details response status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      
      print('📄 Successfully fetched item details');
      
      // Extract and log key information
      if (responseData.containsKey('data')) {
        final itemData = responseData['data'];
        if (itemData is Map<String, dynamic>) {
          print('📄 Item name: ${itemData['name'] ?? 'N/A'}');
          print('📄 Last modified: ${itemData['last_modified_date'] ?? 'N/A'}');
        }
      }
      
      // Log activities count
      if (responseData.containsKey('tasks')) {
        final tasks = responseData['tasks'];
        if (tasks is List) {
          print('📊 Loaded ${tasks.length} activities from preview response');
        }
      }
      
      // Log related data count
      if (responseData.containsKey('related_data')) {
        final relatedData = responseData['related_data'];
        if (relatedData is Map) {
          print('📊 Loaded related data: ${relatedData.keys.length} relationships');
        }
      }
      
      // Log attachments count
      if (responseData.containsKey('attachments')) {
        final attachments = responseData['attachments'];
        if (attachments is List) {
          print('📊 Loaded ${attachments.length} attachments');
        }
      }
      
      // Log history count
      if (responseData.containsKey('history')) {
        final history = responseData['history'];
        if (history is List) {
          print('📊 Loaded ${history.length} history records');
        }
      }
      
      _error = null;
      return responseData;
    } else if (response.statusCode == 401) {
      _error = 'Authentication expired. Please log in again.';
      throw Exception(_error);
    } else if (response.statusCode == 404) {
      _error = 'Item not found.';
      throw Exception(_error);
    } else {
      _error = 'Failed to load item details. Status code: ${response.statusCode}';
      throw Exception(_error);
    }
  } catch (e) {
    _error = 'Error occurred: $e';
    print('❌ Error fetching item details: $e');
    throw Exception(_error);
  }
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
    
    final correctType = _getCorrectType(type);
    final url = '${ApiConfig.baseUrl}/api/$correctType';
    
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

// Update the signature of the uploadFile method in your DataProvider class

Future<Map<String, dynamic>> uploadFile(String objectType, String recordId, File file) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();
  
  Map<String, dynamic> result = {
    'success': false,
    'data': null,
  };
  
  try {
    if (_token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return result;
    }
    
    // Create a multipart request
    var request = http.MultipartRequest('POST', Uri.parse('https://qa.api.bussus.com/v2/api/file'));
    
    // Add headers
    request.headers['Authorization'] = 'Bearer $_token';
    
    // Create JSON data part - as a separate part named 'data'
    var jsonData = json.encode({
      'object': objectType,
      'record_id': recordId
    });
    
    // Add the JSON as a part
    request.fields['data'] = jsonData;
    
    // Add the file
    var fileName = file.path.split('/').last;
    var fileStream = http.ByteStream(file.openRead());
    var fileLength = await file.length();
    
    var multipartFile = http.MultipartFile(
      'file',
      fileStream,
      fileLength,
      filename: fileName
    );
    
    request.files.add(multipartFile);
    
    print('🌐 Uploading file with JSON data to: https://qa.api.bussus.com/v2/api/file');
    print('📤 Uploading file: $fileName');
    print('📤 With JSON data: $jsonData');
    
    // Send the request
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    print('📊 Response status: ${response.statusCode}');
    print('📊 Response body: ${response.body}');
    
    if (response.statusCode == 201) {
      print('📤 File uploaded successfully!');
      
      // Parse the response
      final Map<String, dynamic> responseData = json.decode(response.body) as Map<String, dynamic>;
      
      // Cast inner data to ensure correct typing
      Map<String, dynamic> fileData = {};
      if (responseData.containsKey('data') && responseData['data'] != null) {
        // Cast each key/value pair to ensure they're String/dynamic
        final rawData = responseData['data'];
        if (rawData is Map) {
          rawData.forEach((key, value) {
            fileData[key.toString()] = value;
          });
        }
      }
      
      result = {
        'success': true,
        'data': {
          ...fileData,
          'name': fileName,
          'upload_status': 'completed',
        },
      };
    } else {
      _error = 'Failed to upload file. Status code: ${response.statusCode}';
      print('❌ Failed to upload file: ${response.body}');
    }
  } catch (e) {
    _error = 'Error occurred during file upload: $e';
    print('❌ Error uploading file: $e');
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
  
  return result;
}
// Fixed implementation based on working React code
Future<bool> deleteFile(String fileId, String fileName) async {
  _isLoading = true;
  lastError = null;
  _safeNotifyListeners();
  
  try {
    if (_token.isEmpty) {
      lastError = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return false;
    }
    
    final String endpoint = 'https://qa.api.bussus.com/v2/api/file';
    
    // Create a nested data structure matching the React implementation
    final Map<String, dynamic> payload = {
      'data': {
        'id': fileId,
        'file_path': 'uploads/${fileName.split('/').last}',
      }
    };
    
    print('🗑️ Deleting file with nested payload: ${json.encode(payload)}');
    
    final response = await http.delete(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode(payload),
    );
    
    print('📬 Response: [${response.statusCode}] ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        return true;
      } else {
        lastError = responseData['message'] ?? 'Failed to delete file';
        return false;
      }
    } else {
      lastError = 'Failed to delete file. Status code: ${response.statusCode}';
      return false;
    }
  } catch (e) {
    lastError = 'Error occurred during file deletion: $e';
    return false;
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
}

// Add this method to your DataProvider class
Future<Map<String, dynamic>> updateFileName(Map<String, dynamic> data) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();
  
  Map<String, dynamic> result = {
    'success': false,
    'data': null,
  };
  
  try {
    if (_token.isEmpty) {
      _error = 'Authentication required. Please log in.';
      _isLoading = false;
      _safeNotifyListeners();
      return result;
    }
    
    // Extract the file ID and new name
    final String fileId = data['id'];
    final String newName = data['name'];
    
    // Prepare the request payload according to the expected format
    final Map<String, dynamic> payload = {
      'data': {
        'id': fileId,
        'name': newName,
      }
    };
    
    print('🌐 Updating file name: $payload');
    
    // Make the PATCH request to update the file name
    final response = await http.patch(
      Uri.parse('https://qa.api.bussus.com/v2/api/file'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    
    print('📊 Response status: ${response.statusCode}');
    print('📊 Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      print('✅ File name updated successfully!');
      
      // Parse the response
      final Map<String, dynamic> responseData = json.decode(response.body);
      
      // Extract the returned data
      final Map<String, dynamic> returnedData = responseData['data'] ?? {};
      
      result = {
        'success': true,
        'data': returnedData,
      };
    } else {
      _error = 'Failed to update file name. Status code: ${response.statusCode}';
      print('❌ Failed to update file name: ${response.body}');
    }
  } catch (e) {
    _error = 'Error occurred while updating file name: $e';
    print('❌ Error updating file name: $e');
  } finally {
    _isLoading = false;
    _safeNotifyListeners();
  }
  
  return result;
}

Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData, String token) async {
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
    
    // Using the correct API endpoint
    // final pluralType = _ensurePluralType(type);
    final url = 'https://dev.api.bussus.com/v2/api/leads/task';
    
    // Restructuring the data to match exactly the required format
    final formattedTaskData = {
      'subject': taskData['subject'],
      'status': taskData['status'],
      'due_date': taskData['due_date'],
      'assigned_to_id': taskData['assigned_to_id'],
      'related_to_object_id': taskData['related_object_id']  // Make sure this mapping is correct
    };
    
    print('🌐 Creating new task at $url');
    print('📝 Original task data: $taskData');
    print('📝 Formatted task data: $formattedTaskData');
    
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'data': formattedTaskData
      }),
    );
    
    print('📤 Create response status: ${response.statusCode}');
    print('📤 Create response body: ${response.body}');
    
    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      
      if (responseData['success'] == true) {
        // Refresh task list after creating a new task
        await refreshTaskList();
        
        _isLoading = false;
        _error = null;
        _safeNotifyListeners();
        return {'success': true, 'data': responseData['data']};
      } else {
        String errorMessage = 'Failed to create task';
        if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        } else if (responseData['errors'] != null && responseData['errors'].isNotEmpty) {
          errorMessage = responseData['errors'][0]['error'] ?? errorMessage;
        }
        _error = errorMessage;
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'error': _error};
      }
    } else {
      String errorMessage;
      try {
        final responseData = json.decode(response.body);
        errorMessage = responseData['message'] ?? 'Failed to create task';
      } catch (e) {
        errorMessage = 'Failed to create task. Status code: ${response.statusCode}';
      }
      _error = errorMessage;
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': errorMessage};
    }
  } catch (e) {
    _error = 'Error occurred: $e';
    print('❌ Error creating task: $e');
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': false, 'error': _error.toString()};
  }
}
  
  // This method would refresh the task list
  Future<void> refreshTaskList() async {
    // Implement logic to refresh task list
    // This will depend on how you're storing and managing tasks in your app
    print('🔄 Refreshing task list...');
    
    // Example implementation:
    // await fetchTasks(currentToken);
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
    
    // Use the correct API URL from your example
    final url = 'https://dev.api.bussus.com/v2/api/task';
    
    print('🌐 Sending PATCH request to $url with task ID: $taskId');
    print('📝 Task data: $taskData');
    
    // Format the request body according to your required payload structure
    // This exactly matches the format you provided in your example
    final requestBody = {
      'data': taskData
    };
    
    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );
    
    print('📤 Update response status: ${response.statusCode}');
    print('📤 Update response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      
      // Check if the response indicates success
      if (responseData['success'] == true) {
        
        // Check for errors
        if (responseData['errors'] != null && responseData['errors'].isNotEmpty) {
          final firstError = responseData['errors'][0];
          if (firstError['error'] != null) {
            _error = 'Update failed: ${firstError['error']}';
            _isLoading = false;
            _safeNotifyListeners();
            return {'success': false, 'error': _error};
          }
        }
        
        // Check if there are updated records
        if (responseData['updated_records'] != null && 
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
        _error = responseData['message'] ?? 'Failed to update task';
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

// Add this method to your DataProvider class
Future<Map<String, dynamic>> updateMinimalTask(String taskId, Map<String, dynamic> taskData, String token) async {
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
    
    // API URL
    final url = 'https://dev.api.bussus.com/v2/api/task';
    
    print('🌐 Sending PATCH request to $url with task ID: $taskId');
    print('📝 Minimal task data: $taskData');
    
    // Format the request body exactly as in the original API scheme
    final requestBody = {
      'data': taskData
    };
    
    // Send a raw request to see the actual API response structure
    final http.Response response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );
    
    // Log the complete raw response for debugging
    print('📤 Raw update response status: ${response.statusCode}');
    print('📤 Raw update response body: ${response.body}');
    
    final Map<String, dynamic> responseData = json.decode(response.body);
    
    // Check if the response has errors specific to the task update
    if (responseData['errors'] != null && responseData['errors'].isNotEmpty) {
      // Find the error for our task ID if it exists
      final taskError = responseData['errors'].firstWhere(
        (error) => error['id'] == taskId,
        orElse: () => null
      );
      
      if (taskError != null && taskError['error'] != null) {
        _error = 'Update failed: ${taskError['error']}';
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'error': _error};
      }
    }
    
    // If we made it here, consider it a success even if no records were updated
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': true};
    
  } catch (e) {
    _error = 'Error occurred: $e';
    print('❌ Error updating task: $e');
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': false, 'error': _error.toString()};
  }
}
Future<Map<String, dynamic>> fetchRelatedActivities(String parentId, String token) async {
    try {
      // Log the request
      print('🌐 Fetching related activities for parent ID: $parentId');
      
      // Construct the API URL for activities related to this parent
      final url = Uri.parse('${ApiConfig.baseUrl}/v2/api/task?related_to=$parentId');
      
      // Make the request
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      // Check if request was successful
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Log success
        print('📤 Activities response status: ${response.statusCode}');
        print('📊 Found ${responseData['data']?.length ?? 0} related activities');
        
        // Return a properly formatted result
        return {
          'success': true,
          'data': responseData['data'] ?? [],
        };
      } else {
        // Log failure
        print('❌ Error fetching activities: Status ${response.statusCode}');
        print('❌ Response: ${response.body}');
        
        // Return error information
        return {
          'success': false,
          'error': 'Failed to fetch activities. Status: ${response.statusCode}',
          'data': [],
        };
      }
    } catch (e) {
      // Log exception
      print('❌ Exception fetching activities: $e');
      
      // Return error information
      return {
        'success': false,
        'error': 'Exception occurred: $e',
        'data': [],
      };
    }
  }
 Future<Map<String, dynamic>> getUsers(String token) async {
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
    
    // Updated URL to match the working endpoint
    final url = 'https://dev.api.bussus.com/v2/api/lookup/users?search=';
    
    print('🌐 Fetching users from $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    print('📥 Users response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final dynamic responseData = json.decode(response.body);
      print('📋 Raw response data type: ${responseData.runtimeType}');
      
      // Handle direct array response
      if (responseData is List) {
        print('✅ Received direct array with ${responseData.length} users');
        
        // Validate each user object
        List<Map<String, dynamic>> validUsers = [];
        for (int i = 0; i < responseData.length; i++) {
          final user = responseData[i];
          if (user is Map<String, dynamic>) {
            // Ensure required fields exist
            if (user.containsKey('id') && user.containsKey('name')) {
              validUsers.add({
                'id': user['id']?.toString() ?? '',
                'name': user['name']?.toString() ?? '',
                'email': user['email']?.toString() ?? '',
                'first_name': user['first_name']?.toString() ?? '',
                'last_name': user['last_name']?.toString() ?? '',
              });
            } else {
              print('⚠️ Skipping invalid user at index $i: missing id or name');
            }
          } else {
            print('⚠️ Skipping invalid user at index $i: not a map');
          }
        }
        
        _isLoading = false;
        _error = null;
        _safeNotifyListeners();
        return {'success': true, 'data': validUsers};
      }
      // Handle wrapped response (fallback)
      else if (responseData is Map && responseData.containsKey('data')) {
        print('✅ Received wrapped response');
        final userData = responseData['data'];
        if (userData is List) {
          _isLoading = false;
          _error = null;
          _safeNotifyListeners();
          return {'success': true, 'data': userData};
        } else {
          _error = 'Invalid data format in response';
          _isLoading = false;
          _safeNotifyListeners();
          return {'success': false, 'error': _error};
        }
      }
      // Handle unexpected response format
      else {
        _error = 'Unexpected response format: ${responseData.runtimeType}';
        print('❌ $_error');
        print('📋 Response data: $responseData');
        _isLoading = false;
        _safeNotifyListeners();
        return {'success': false, 'error': _error};
      }
    } else {
      String errorMessage;
      try {
        final responseData = json.decode(response.body);
        errorMessage = responseData['message'] ?? 'Failed to fetch users';
      } catch (e) {
        errorMessage = 'Failed to fetch users. Status code: ${response.statusCode}';
      }
      _error = errorMessage;
      _isLoading = false;
      _safeNotifyListeners();
      return {'success': false, 'error': errorMessage};
    }
  } catch (e, stackTrace) {
    _error = 'Error occurred: $e';
    print('❌ Error fetching users: $e');
    print('📍 Stack trace: $stackTrace');
    _isLoading = false;
    _safeNotifyListeners();
    return {'success': false, 'error': _error.toString()};
  }
}


 Future<void> searchData(String type, String query, String token) async {
  _isLoading = true;
  _error = null;
  _safeNotifyListeners();
  
  try {
    // Ensure type is in plural form
    final correctType = _getCorrectType(type);
    
    // Construct the URL with search parameter using ApiConfig
    final url = Uri.parse('${ApiConfig.baseUrl}/api/listview/$correctType?listview=all&search=$query&limit=10&offset=0');
    print('🔍 Searching $correctType with query: "$query"');
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