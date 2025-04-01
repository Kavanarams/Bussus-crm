import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dynamic_model.dart';

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

  // Remove context dependency
  DataProvider();

  List<DynamicModel> get items => _filteredItems.isEmpty && _activeFilters.isEmpty ? _items : _filteredItems;
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

  // Updated to require token as a parameter
  Future<void> loadData(String type, String token) async {
    _token = token;
    _type = type;

    // Reset state when loading new type
    _items = [];
    _filteredItems = [];
    _activeFilters = {};
    _sortColumn = null;
    _sortAscending = true;
    _error = null;
    _currentListViewId = null;

    _isLoading = true;
    notifyListeners();

    try {
      String endpoint = 'http://88.222.241.78/v2/api/listview/$type';
      print('🌐 Fetching data from: $endpoint');
      print('🔑 Using token: ${token.isNotEmpty ? token.substring(0, 10) + '...' : 'Empty token'}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _items = [];
        _filteredItems = [];
        _isLoading = false;
        notifyListeners();
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

        // Apply default sorting (newest first)
        _sortByCreationDate();

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
      notifyListeners();
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
    notifyListeners();

    try {
      print('🌐 Fetching data from: $endpoint');
      print('🔑 Using token: ${token.isNotEmpty ? token.substring(0, 10) + '...' : 'Empty token'}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _items = [];
        _filteredItems = [];
        _isLoading = false;
        notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> applyFilter(String field, String? value) async {
    Map<String, String> filters = {};
    if (value != null) {
      filters[field] = value;
    } else {
      filters[field] = '';  // Use empty string instead of null
    }

    await applyFilters(filters, _token, _type);
  }

  // Updated to use remote API filtering with improved notification
  // Fix for DataProvider class:

  Future<void> applyFilters(Map<String, String> filters, String token, String type) async {
    _isLoading = true;
    _activeFilters = Map<String, dynamic>.from(filters);
    notifyListeners();

    try {
      // Only proceed if we have a valid list view ID
      if (_currentListViewId == null) {
        _error = 'No list view ID available for filtering';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Build the filters array in the required format
      List<Map<String, String>> filtersList = [];
      filters.forEach((field, value) {
        if (value.isNotEmpty) {
          filtersList.add({
            'field': field,
            'operator': 'equals', // Default to equals, could be parameterized
            'value': value
          });
        }
      });

      // Construct the payload as per API requirements
      final Map<String, dynamic> payload = {
        'data': {
          'filters': filtersList,
          'filter_logic': '', // Empty for now, could be parameterized
          'id': _currentListViewId
        }
      };

      print('🔍 Applying filters with payload: ${json.encode(payload)}');

      // Send the PATCH request
      final response = await http.patch(
        Uri.parse('http://88.222.241.78/v2/api/listview'),
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

        _filteredItems = apiResponse.data;
        _items = apiResponse.data; // Update _items to display filtered data
        _currentResponse = apiResponse;
        _error = null;

        print('📊 Applied filters. Filtered items count: ${_filteredItems.length}');
      } else {
        _error = 'Failed to apply filters. Status code: ${response.statusCode}';
        print('❌ Error applying filters: ${response.body}');
      }
    } catch (e) {
      _error = 'Error applying filters: $e';
      print('❌ Error applying filters: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearFilters() async {
    _isLoading = true;
    _activeFilters = {};
    notifyListeners();

    try {
      // Need to explicitly clear filters on the server
      if (_currentListViewId != null) {
        String endpoint = 'http://88.222.241.78/v2/api/listview';

        // Create empty filter payload as per API requirements
        final Map<String, dynamic> payload = {
          'data': {
            'filters': [],
            'filter_logic': '',
            'id': _currentListViewId
          }
        };

        print('🔍 Clearing filters on server for listview: $_currentListViewId');
        print('🔍 Using payload: ${json.encode(payload)}');

        final response = await http.patch(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
          body: json.encode(payload),
        );

        print('📤 Clear filter response status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

          // Update both _filteredItems and _items with the response data
          _filteredItems = apiResponse.data;
          _items = apiResponse.data;
          _currentResponse = apiResponse;
          _error = null;

          // Apply default sorting (newest first)
          _sortByCreationDate();

          print('📊 Cleared filters - items count: ${_items.length}');
        } else {
          _error = 'Failed to clear filters. Status code: ${response.statusCode}';
          print('❌ Error response: ${response.body}');
        }
      } else {
        // If no listview ID, just reload data
        await loadData(_type, _token);
      }
    } catch (e) {
      _error = 'Error occurred while clearing filters: $e';
      print('❌ Error clearing filters: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _sortColumn = null;
    _sortAscending = true;

    // Reset to original data order
    if (_currentResponse != null) {
      // Reset to original data order
      _items = List<DynamicModel>.from(_currentResponse!.data);
      
      // Reset filtered items to match the main items
      _filteredItems = List<DynamicModel>.from(_items);
      
      // Apply default sorting (newest first)
      _sortByCreationDate();
    }

    notifyListeners();
  }

  // Apply sorting only (keep separate from filtering now)
  void _applySorting() {
    List<DynamicModel> result = List.from(_filteredItems.isEmpty ? _items : _filteredItems);

    // Apply sorting
    if (_sortColumn == null) {
      // Sort by creation date if no explicit sort column
      result.sort((a, b) {
        String dateA = a.getStringAttribute('created_date');
        String dateB = b.getStringAttribute('created_date');

        if (dateA.isNotEmpty && dateB.isNotEmpty) {
          try {
            DateTime dtA = DateTime.parse(dateA);
            DateTime dtB = DateTime.parse(dateB);
            return dtB.compareTo(dtA); // Newest first
          } catch (e) {
            return dateB.compareTo(dateA);
          }
        }
        return 0;
      });
    } else {
      // Sort by selected column
      result.sort((a, b) {
        String valA = a.getStringAttribute(_sortColumn!).toLowerCase();
        String valB = b.getStringAttribute(_sortColumn!).toLowerCase();

        // Try numeric comparison if possible
        double? numA = double.tryParse(valA);
        double? numB = double.tryParse(valB);

        if (numA != null && numB != null) {
          return _sortAscending ? numA.compareTo(numB) : numB.compareTo(numA);
        }

        // Otherwise do string comparison
        return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
      });
    }

    // Update filtered items if we had filtered results
    if (_filteredItems.isNotEmpty) {
      _filteredItems = result;
    } else {
      _items = result;
    }
    notifyListeners();
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
    String endpoint = 'http://88.222.241.78/v2/api/$type';
    _isLoading = true;
    notifyListeners();

    try {
      print('🌐 Creating new $type with data: ${formData.keys.join(', ')}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _isLoading = false;
        notifyListeners();
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

            notifyListeners();
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
        notifyListeners();
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Error occurred: $e';
      _error = errorMsg;
      print('❌ Error creating data: $e');
      notifyListeners();
      return {'success': false, 'message': errorMsg};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateItem(String type, String itemId, Map<String, dynamic> formData, String token) async {
    String endpoint = 'http://88.222.241.78/v2/api/$type/$itemId';
    _isLoading = true;
    notifyListeners();

    try {
      print('🌐 Updating $type with ID: $itemId');
      print('🌐 Update data: ${formData.keys.join(', ')}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _isLoading = false;
        notifyListeners();
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

              notifyListeners();
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
        notifyListeners();
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Error occurred: $e';
      _error = errorMsg;
      print('❌ Error updating data: $e');
      notifyListeners();
      return {'success': false, 'message': errorMsg};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> forceRefreshData(String token, String type) async {
    if (_currentListViewId == null) {
      print('Cannot refresh: No list view ID available');
      return false;
    }

    _isLoading = true;
    notifyListeners(); // Notify loading state

    try {
      // Direct API call to get fresh data
      final response = await http.get(
        Uri.parse('http://88.222.241.78/v2/api/listview/${_currentListViewId}'),
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
        notifyListeners();
        return true;
      } else {
        _error = 'Failed to refresh data. Status code: ${response.statusCode}';
        print('❌ Failed to refresh: ${response.statusCode}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error refreshing data: $e';
      print('❌ Error refreshing: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData, String token, String type) async {
    // Determine the correct endpoint based on the object type
    String endpoint = 'http://88.222.241.78/v2/api/$type/task';
    _isLoading = true;
    notifyListeners();

    try {
      print('🌐 Creating new task for $type with data: ${taskData.keys.join(', ')}');

      // Check if token exists
      if (token.isEmpty) {
        _error = 'Authentication required. Please log in.';
        _isLoading = false;
        notifyListeners();
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
        notifyListeners();
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      String errorMsg = 'Error occurred: $e';
      _error = errorMsg;
      print('❌ Error creating task: $e');
      notifyListeners();
      return {'success': false, 'message': errorMsg};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}