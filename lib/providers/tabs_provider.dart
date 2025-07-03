import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/tab_item.dart';
import 'auth_provider.dart';

class TabsProvider with ChangeNotifier {
  List<TabItem> _tabs = [];
  bool _isLoading = false;
  String _error = '';
  bool _hasInitialized = false;

  List<TabItem> get tabs => _tabs;
  bool get isLoading => _isLoading;
  String get error => _error;
  bool get hasInitialized => _hasInitialized;

  Future<void> fetchTabs(AuthProvider authProvider) async {
    // Prevent multiple simultaneous requests
    if (_isLoading) {
      print('⚠️ Tabs already loading, skipping duplicate request');
      return;
    }
    
    print('🔄 Starting fetchTabs...');
    _setLoadingState(true);

    try {
      print('📡 Making API request to fetch tabs...');
      final response = await http.get(
        Uri.parse('https://dev.api.bussus.com/v2/api/objects/tabs?app=sales'),
        headers: {
          'Authorization': 'Bearer ${authProvider.token}',
          'Content-Type': 'application/json',
        },
      );

      print('📡 Tabs API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body;
        print('📡 Raw Response Body Length: ${responseBody.length}');
        
        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }
        
        final List<dynamic> data = json.decode(responseBody);
        print('📊 Received ${data.length} tabs from API');
        
        // Debug: Print each tab data (first few only to avoid spam)
        for (int i = 0; i < data.length && i < 3; i++) {
          print('📋 Tab $i: ${data[i]}');
        }
        
        final List<TabItem> newTabs = data.map((json) {
          try {
            return TabItem.fromJson(json);
          } catch (e) {
            print('❌ Error parsing tab: $json, Error: $e');
            rethrow;
          }
        }).toList();
        
        // Sort tabs alphabetically by plural_label for better UX
        newTabs.sort((a, b) => a.pluralLabel.compareTo(b.pluralLabel));
        
        _tabs = newTabs;
        _error = '';
        _hasInitialized = true;
        
        print('✅ Successfully loaded ${_tabs.length} tabs');
        print('📋 Available tab names: ${_tabs.map((t) => t.name).take(5).join(', ')}${_tabs.length > 5 ? '...' : ''}');
        
      } else {
        final errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        print('❌ Failed to fetch tabs: $errorMessage');
        print('Response body: ${response.body}');
        
        _error = 'Failed to load menu items ($errorMessage)';
        _tabs = [];
      }
    } catch (e) {
      print('❌ Exception in fetchTabs: $e');
      _error = 'Network error: ${e.toString()}';
      _tabs = [];
    } finally {
      _setLoadingState(false);
      print('🔄 fetchTabs completed. Loading: $_isLoading, Error: $_error, Tabs: ${_tabs.length}');
    }
  }

  Future<void> refreshTabs(AuthProvider authProvider) async {
    print('🔄 Refreshing tabs...');
    _tabs = [];
    _error = '';
    _hasInitialized = false;
    notifyListeners(); // Notify immediately to show loading state
    await fetchTabs(authProvider);
  }

  void _setLoadingState(bool loading) {
    _isLoading = loading;
    print('🔄 Setting loading state to: $loading');
    notifyListeners();
  }

  // Helper method to get tab by name with better error handling
  TabItem? getTabByName(String name) {
    if (_isLoading) {
      print('⚠️ Tabs are still loading, cannot find tab: $name');
      return null;
    }
    
    if (_tabs.isEmpty) {
      print('⚠️ No tabs available, cannot find tab: $name');
      return null;
    }
    
    try {
      // Try exact match first (case insensitive)
      for (final tab in _tabs) {
        if (tab.name.toLowerCase() == name.toLowerCase()) {
          print('✅ Found exact match for tab: $name -> ${tab.name}');
          return tab;
        }
      }
      
      // Try partial match
      for (final tab in _tabs) {
        if (tab.name.toLowerCase().contains(name.toLowerCase()) ||
            tab.pluralLabel.toLowerCase().contains(name.toLowerCase()) ||
            tab.label.toLowerCase().contains(name.toLowerCase())) {
          print('✅ Found partial match for tab: $name -> ${tab.name}');
          return tab;
        }
      }
      
      print('⚠️ Tab not found: $name');
      print('📋 Available tabs: ${_tabs.map((t) => '${t.name}(${t.pluralLabel})').take(3).join(', ')}${_tabs.length > 3 ? '...' : ''}');
      return null;
    } catch (e) {
      print('❌ Error finding tab $name: $e');
      return null;
    }
  }

  // Helper method to get icon for a tab name
  String getIconForTab(String name) {
    final tab = getTabByName(name);
    if (tab != null) {
      print('🎯 Found icon for $name: ${tab.icon}');
      return tab.icon;
    }
    print('⚠️ Using default icon for $name');
    return 'list';
  }

  // Helper method to get display name for a tab
  String getDisplayNameForTab(String name) {
    final tab = getTabByName(name);
    if (tab != null) {
      print('🎯 Found display name for $name: ${tab.pluralLabel}');
      return tab.pluralLabel;
    }
    print('⚠️ Using default display name for $name');
    return name.toUpperCase();
  }

  // Helper method to get color for a tab
  String? getColorForTab(String name) {
    final tab = getTabByName(name);
    if (tab != null && tab.iconColor != null && tab.iconColor!.isNotEmpty) {
      print('🎯 Found color for $name: ${tab.iconColor}');
      return tab.iconColor;
    }
    print('⚠️ No color found for $name');
    return null;
  }

  // Helper method to check if tabs are loaded and contain a specific tab
  bool hasTab(String name) {
    return !_isLoading && _tabs.isNotEmpty && getTabByName(name) != null;
  }

  // Helper method to wait for tabs to load
  Future<bool> waitForTabsToLoad({int maxWaitSeconds = 10}) async {
    int waitedMs = 0;
    const checkIntervalMs = 100;
    
    while (_isLoading && waitedMs < maxWaitSeconds * 1000) {
      await Future.delayed(Duration(milliseconds: checkIntervalMs));
      waitedMs += checkIntervalMs;
    }
    
    final success = !_isLoading && _tabs.isNotEmpty && _error.isEmpty;
    print('⏱️ waitForTabsToLoad result: success=$success, waited=${waitedMs}ms, tabs=${_tabs.length}');
    return success;
  }

  // Method to clear all data (useful for logout)
  void clear() {
    _tabs = [];
    _isLoading = false;
    _error = '';
    _hasInitialized = false;
    notifyListeners();
    print('🧹 TabsProvider cleared');
  }
}