import 'package:flutter/material.dart';
import '../models/dashboard_item.dart';
import '../services/dashboard_service.dart';
import 'auth_provider.dart';

class DashboardProvider extends ChangeNotifier {
  List<DashboardItem> _items = [];
  bool _isLoading = false;
  String _error = '';
  String _dashboardName = '';

  List<DashboardItem> get items => _items;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get dashboardName => _dashboardName;

  DashboardService? _service;

  // Initialize with AuthProvider
  void initialize(AuthProvider authProvider) {
    _service = DashboardService(authProvider: authProvider);
  }

  Future<void> fetchDashboard() async {
    if (_service == null) {
      _error = 'Dashboard service not initialized with auth provider';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final dashboard = await _service!.fetchDashboard();
      _items = dashboard.items;
      _dashboardName = dashboard.name;
      _isLoading = false;

      // Debug print
      print('Dashboard provider updated with ${_items.length} items');

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
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