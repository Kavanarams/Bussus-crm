import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/apps.dart';
import '../models/tab_item.dart';
import 'auth_provider.dart';

class AppsProvider with ChangeNotifier {
  List<App> _apps = [];
  bool _isLoading = false;
  String _error = '';
  App? _selectedApp;
  List<TabItem> _appTabs = [];
  bool _isLoadingTabs = false;
  String _tabsError = '';

  List<App> get apps => _apps;
  bool get isLoading => _isLoading;
  String get error => _error;
  App? get selectedApp => _selectedApp;
  List<TabItem> get appTabs => _appTabs;
  bool get isLoadingTabs => _isLoadingTabs;
  String get tabsError => _tabsError;

  // Fetch all available apps
  Future<void> fetchApps(AuthProvider authProvider) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('🔄 Fetching apps from API');
      
      final response = await http.get(
        Uri.parse('https://dev.api.bussus.com/v2/api/setup/apps'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Apps API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _apps = data.map((json) => App.fromJson(json)).toList();
        
        print('✅ Successfully loaded ${_apps.length} apps');
        
        // Set default app to 'sales' if available
        if (_selectedApp == null) {
          final salesApp = _apps.firstWhere(
            (app) => app.name.toLowerCase() == 'sales',
            orElse: () => _apps.isNotEmpty ? _apps.first : App(
              id: 'default',
              name: 'sales',
              label: 'Sales',
              tabs: [],
              developer: '',
              setupExperience: '',
              navigationStyle: '',
              formFactor: '',
              disableEndUserPersonalisation: false,
              disableTemporaryTabs: false,
              useAppImageColorForOrgTheme: false,
              useOmniChannelSidebar: false,
              createdBy: '',
              lastModifiedBy: '',
              createdDate: DateTime.now(),
              lastModifiedDate: DateTime.now(),
              organisation: '',
            ),
          );
          
          await selectApp(salesApp, authProvider);
        }
        
        _error = '';
      } else {
        _error = 'Failed to load apps: ${response.statusCode}';
        print('❌ Apps API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _error = 'Network error: $e';
      print('❌ Apps fetch exception: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Select an app and fetch its tabs
  Future<void> selectApp(App app, AuthProvider authProvider) async {
    if (_selectedApp?.id == app.id && _appTabs.isNotEmpty) {
      print('📱 App ${app.name} already selected with tabs loaded');
      return;
    }

    print('🔄 Selecting app: ${app.name}');
    _selectedApp = app;
    notifyListeners();

    await fetchAppTabs(app.name, authProvider);
  }

  // Fetch tabs for a specific app
  Future<void> fetchAppTabs(String appName, AuthProvider authProvider) async {
    if (_isLoadingTabs) return;

    _isLoadingTabs = true;
    _tabsError = '';
    notifyListeners();

    try {
      print('🔄 Fetching tabs for app: $appName');
      
      final response = await http.get(
        Uri.parse('https://dev.api.bussus.com/v2/api/objects/tabs?app=$appName'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      print('📡 App Tabs API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _appTabs = data.map((json) => TabItem.fromJson(json)).toList();
        
        print('✅ Successfully loaded ${_appTabs.length} tabs for app $appName');
        _tabsError = '';
      } else {
        _tabsError = 'Failed to load app tabs: ${response.statusCode}';
        print('❌ App Tabs API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _tabsError = 'Network error: $e';
      print('❌ App tabs fetch exception: $e');
    } finally {
      _isLoadingTabs = false;
      notifyListeners();
    }
  }

  // Refresh apps
  Future<void> refreshApps(AuthProvider authProvider) async {
    _apps.clear();
    _selectedApp = null;
    _appTabs.clear();
    await fetchApps(authProvider);
  }

  // Get first 4 tabs for bottom navigation
  List<TabItem> getBottomNavTabs() {
    return _appTabs.take(4).toList();
  }

  // Get display name for tab
  String getDisplayNameForTab(String tabName) {
    final tab = _appTabs.firstWhere(
      (tab) => tab.name == tabName,
      orElse: () => TabItem(
        id: '',
        name: tabName,
        label: tabName,
        pluralLabel: tabName,
        icon: '',
        iconColor: null,
      ),
    );
    return tab.pluralLabel;
  }

  // Get tab by name
  TabItem? getTabByName(String tabName) {
    try {
      return _appTabs.firstWhere((tab) => tab.name == tabName);
    } catch (e) {
      return null;
    }
  }

  // Get color for tab
  String? getColorForTab(String tabName) {
    final tab = getTabByName(tabName);
    return tab?.iconColor;
  }

  // Clear all data
  void clearData() {
    _apps.clear();
    _selectedApp = null;
    _appTabs.clear();
    _error = '';
    _tabsError = '';
    _isLoading = false;
    _isLoadingTabs = false;
    notifyListeners();
  }
}