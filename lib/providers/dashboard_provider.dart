import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/dashboard_item.dart';
import '../config/api_config.dart';
import 'auth_provider.dart';

class DashboardProvider with ChangeNotifier {
  List<DashboardItem> _items = [];
  bool _isLoading = false;
  String _error = '';
  String _dashboardName = '';

  List<DashboardItem> get items => _items;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get dashboardName => _dashboardName;

  Future<void> initialize(AuthProvider authProvider) async {
    await fetchDashboard(authProvider);
  }

  Future<void> fetchDashboard(AuthProvider authProvider) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('🔍 Fetching dashboard data...');
      final response = await http.get(
        Uri.parse('https://qa.api.bussus.com/v2/api/setup/dashboard'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      print('📤 Dashboard response status code: ${response.statusCode}');
      print('📤 Dashboard response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final dashboard = responseData['dashboard'] as Map<String, dynamic>?;
        final components = responseData['components'] as List<dynamic>?;

        if (dashboard != null && components != null) {
          _dashboardName = dashboard['name'] ?? 'Home Dashboard';
          
          // Create widgets based on the components array
          _items = components.map((component) {
            final componentData = component as Map<String, dynamic>;
            
            // Safely extract nested data
            final geometry = componentData['geometry'] is Map 
                ? componentData['geometry'] as Map<String, dynamic> 
                : <String, dynamic>{};
            final data = componentData['data'] is Map 
                ? componentData['data'] as Map<String, dynamic> 
                : <String, dynamic>{};
            
            return DashboardItem(
              id: componentData['id']?.toString() ?? '',
              name: componentData['name']?.toString() ?? '',
              title: componentData['name']?.toString() ?? '',
              type: _determineWidgetType(componentData['type']?.toString() ?? ''),
              order: (geometry['y'] ?? 0).toInt(),
              config: {
                'type': componentData['type']?.toString() ?? '',
                'data_source': componentData['data_source']?.toString() ?? '',
                'filters': componentData['filters'] is List ? componentData['filters'] : [],
                'metric_config': componentData['metric_config'] is Map ? componentData['metric_config'] : {},
                'chart_config': componentData['chart_config'] is Map ? componentData['chart_config'] : {},
                'geometry': geometry,
              },
              data: data,
              isActive: true,
            );
          }).toList();
          
          _error = '';
          print('📊 Loaded ${_items.length} dashboard items');
        } else {
          _error = 'Invalid dashboard data format';
          print('❌ Invalid dashboard data format');
        }
      } else {
        _error = 'Failed to load dashboard. Status code: ${response.statusCode}';
        print('❌ Error loading dashboard: $_error');
      }
    } catch (e) {
      _error = 'Error loading dashboard: $e';
      print('❌ Exception loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _determineWidgetType(String componentType) {
    // Determine widget type based on component type
    switch (componentType.toLowerCase()) {
      case 'pie_chart':
        return 'chart';
      case 'line_chart':
        return 'chart';
      case 'bar_chart':
        return 'chart';
      case 'list':
        return 'list';
      default:
        return 'stats';
    }
  }

  Map<String, dynamic> _createDefaultConfig(String componentName) {
    // Create default configuration based on component name
    if (componentName.toLowerCase().contains('card')) {
      return {
        'type': 'lead',
        'preview': 'Recent leads will be shown here',
      };
    } else if (componentName.toLowerCase().contains('line')) {
      return {
        'chartType': 'line',
        'data': [
          {'x': 'Jan', 'y': 10},
          {'x': 'Feb', 'y': 15},
          {'x': 'Mar', 'y': 20},
        ],
      };
    } else if (componentName.toLowerCase().contains('pie')) {
      return {
        'chartType': 'pie',
        'data': [
          {'label': 'Category 1', 'value': 30},
          {'label': 'Category 2', 'value': 70},
        ],
      };
    } else {
      return {
        'total': '100',
        'active': '75',
        'pending': '25',
      };
    }
  }

  Map<String, dynamic> _createDefaultData(String componentName) {
    // Create default data based on component name
    if (componentName.toLowerCase().contains('card')) {
      return {
        'items': [
          {'id': 1, 'title': 'Sample Lead 1', 'status': 'New'},
          {'id': 2, 'title': 'Sample Lead 2', 'status': 'In Progress'},
        ],
      };
    } else if (componentName.toLowerCase().contains('line')) {
      return {
        'points': [
          {'x': 0, 'y': 10},
          {'x': 1, 'y': 15},
          {'x': 2, 'y': 20},
        ],
      };
    } else if (componentName.toLowerCase().contains('pie')) {
      return {
        'sections': [
          {'label': 'Category 1', 'value': 30},
          {'label': 'Category 2', 'value': 70},
        ],
      };
    } else {
      return {
        'stats': {
          'total': 100,
          'active': 75,
          'pending': 25,
        },
      };
    }
  }

  Future<void> refreshDashboard(AuthProvider authProvider) async {
    await fetchDashboard(authProvider);
  }

  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final DashboardItem item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    notifyListeners();
  }
}