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

  // Getters for filter and sort state
  Map<String, dynamic> get activeFilters => _activeFilters;
  String? get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  // Updated to require token as a parameter
  Future<void> loadData(String type, String token) async {
    String endpoint = 'http://88.222.241.78/v2/api/listview/$type';
    await fetchData(endpoint, token);

    // Apply default sorting (newest first)
    _sortByCreationDate();

    // Reset filtered items and active filters to show the full sorted list
    _filteredItems = [];
    _activeFilters = {};
    notifyListeners();
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

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final ApiResponse apiResponse = ApiResponse.fromJson(responseData);

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
      } else if (response.statusCode == 401) {
        _error = 'Authentication expired. Please log in again.';
        _items = [];
        _filteredItems = [];
        // Don't navigate here, just set the error
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

  // Apply filter based on column name and value
  void applyFilter(String column, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      _activeFilters.remove(column);
    } else {
      _activeFilters[column] = value;
    }

    _applyFiltersAndSort();
  }

  // Clear all filters
  void clearFilters() {
    _activeFilters = {};
    _filteredItems = [];
    notifyListeners();
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

    _applyFiltersAndSort();
  }

  // Clear sorting
  void clearSort() {
    _sortColumn = null;
    _applyFiltersAndSort();
  }

  // Apply both filters and sorting
  void _applyFiltersAndSort() {
    List<DynamicModel> result = List.from(_items);

    // Apply filters first
    if (_activeFilters.isNotEmpty) {
      result = result.where((item) {
        bool passes = true;
        for (var entry in _activeFilters.entries) {
          final columnValue = item.getStringAttribute(entry.key).toLowerCase();
          final filterValue = entry.value.toString().toLowerCase();

          if (!columnValue.contains(filterValue)) {
            passes = false;
            break;
          }
        }
        return passes;
      }).toList();
    }

    // Then apply sorting
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
      // Your existing sorting code for other columns
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

    _filteredItems = result;
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

  // Modified createItem method to ensure new items show at the top
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
              _applyFiltersAndSort();
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

  // Modified updateItem method to ensure updated items show at the correct position
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
                _applyFiltersAndSort();
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
}