import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../models/tab_item.dart';
import '../models/apps.dart';
import 'home_screen.dart';
import '../providers/tabs_provider.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    print('📱 MenuScreen initialized');
    // Use addPostFrameCallback to ensure the widget is fully built before loading data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    if (!mounted) return;
    
    try {
      final appsProvider = Provider.of<AppsProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      print('🔄 Loading initial data...');
      
      // First load apps if not already loaded
      if (appsProvider.apps.isEmpty && !appsProvider.isLoading) {
        print('🔄 Loading apps data...');
        appsProvider.fetchApps(authProvider).then((_) {
          // After apps are loaded, set default app to 'sales' and load its tabs
          if (appsProvider.apps.isNotEmpty && appsProvider.selectedApp == null) {
            final salesApp = appsProvider.apps.firstWhere(
              (app) => app.name.toLowerCase() == 'sales',
              orElse: () => appsProvider.apps.first,
            );
            print('🔄 Setting default app to: ${salesApp.name}');
            appsProvider.selectApp(salesApp, authProvider);
          }
        });
      } else if (appsProvider.apps.isNotEmpty && appsProvider.selectedApp == null) {
        // Apps already loaded but no selected app, set default to sales
        final salesApp = appsProvider.apps.firstWhere(
          (app) => app.name.toLowerCase() == 'sales',
          orElse: () => appsProvider.apps.first,
        );
        print('🔄 Setting default app to: ${salesApp.name}');
        appsProvider.selectApp(salesApp, authProvider);
      }
    } catch (e) {
      print('❌ Error loading initial data: $e');
      // Handle the case where provider is not available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize menu. Please restart the app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _refreshApps() {
    if (!mounted) return;
    print('🔄 Refresh apps button pressed');
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final appsProvider = Provider.of<AppsProvider>(context, listen: false);
      appsProvider.refreshApps(authProvider);
    } catch (e) {
      print('❌ Error refreshing apps: $e');
    }
  }

  void _onSearchPressed() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    print('🔍 Search ${_isSearchActive ? 'activated' : 'deactivated'}');
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
    print('🔍 Search query: $_searchQuery');
  }

  List<TabItem> _getFilteredTabs(List<TabItem> tabs) {
    if (_searchQuery.isEmpty) {
      return tabs;
    }
    
    return tabs.where((tab) {
      return tab.pluralLabel.toLowerCase().contains(_searchQuery) ||
             tab.name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _onNotificationPressed() {
    print('🔔 Notification button pressed');
    // Add your notification functionality here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notifications to be implemented')),
    );
  }

  void _showAppSwitcher() {
    try {
      final appsProvider = Provider.of<AppsProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.6, // Reduced height
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 8, bottom: 12), // Reduced margins
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header - Reduced padding
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
                child: Row(
                  children: [
                    Icon(Icons.apps, color: Colors.blue[600], size: 24), // Reduced icon size
                    SizedBox(width: 10), // Reduced spacing
                    Text(
                      'Switch Application',
                      style: TextStyle(
                        fontSize: 18, // Reduced font size
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[600], size: 20), // Reduced icon size
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 18, // Reduced splash radius
                      padding: EdgeInsets.all(4), // Reduced padding
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32), // Smaller button
                    ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                height: 1,
                color: Colors.grey[200],
              ),
              SizedBox(height: 12), // Reduced spacing
              // Apps list
              Expanded(
                child: Consumer<AppsProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading applications...',
                              style: TextStyle(
                                fontSize: 14, // Reduced font size
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (provider.error.isNotEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 40, color: Colors.red[400]), // Reduced icon size
                            SizedBox(height: 12), // Reduced spacing
                            Text(
                              'Failed to load applications',
                              style: TextStyle(
                                fontSize: 16, // Reduced font size
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 6), // Reduced spacing
                            Text(
                              provider.error,
                              style: TextStyle(color: Colors.red[600], fontSize: 12), // Reduced font size
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => provider.fetchApps(authProvider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Reduced padding
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('Retry', style: TextStyle(fontSize: 14)), // Reduced font size
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.apps.length,
                      separatorBuilder: (context, index) => SizedBox(height: 8), // Reduced spacing
                      itemBuilder: (context, index) {
                        final app = provider.apps[index];
                        final isSelected = provider.selectedApp?.id == app.id;

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[50] : Colors.white,
                            borderRadius: BorderRadius.circular(10), // Reduced border radius
                            border: Border.all(
                              color: isSelected ? Colors.blue[200]! : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6, // Reduced blur
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
                            leading: Container(
                              width: 40, // Reduced size
                              height: 40, // Reduced size
                              decoration: BoxDecoration(
                                color: app.color != null 
                                  ? Color(int.parse('FF${app.color!.replaceAll('#', '')}', radix: 16))
                                  : Colors.blue[600],
                                borderRadius: BorderRadius.circular(10), // Reduced border radius
                                boxShadow: [
                                  BoxShadow(
                                    color: (app.color != null 
                                      ? Color(int.parse('FF${app.color!.replaceAll('#', '')}', radix: 16))
                                      : Colors.blue[600]!).withOpacity(0.3),
                                    blurRadius: 6, // Reduced blur
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: app.image != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      app.image!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            app.label.isNotEmpty ? app.label[0].toUpperCase() : 'A',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16, // Reduced font size
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      app.label.isNotEmpty ? app.label[0].toUpperCase() : 'A',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16, // Reduced font size
                                      ),
                                    ),
                                  ),
                            ),
                            title: Text(
                              app.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14, // Reduced font size
                                color: isSelected ? Colors.blue[700] : Colors.grey[800],
                              ),
                            ),
                            subtitle: app.description?.isNotEmpty == true 
                              ? Text(
                                  app.description!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12, // Reduced font size
                                  ),
                                  maxLines: 1, // Reduced max lines
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                            trailing: Container(
                              width: 24, // Reduced size
                              height: 24, // Reduced size
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue[600] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isSelected ? Icons.check : Icons.arrow_forward_ios,
                                color: isSelected ? Colors.white : Colors.grey[600],
                                size: isSelected ? 16 : 12, // Reduced icon size
                              ),
                            ),
                            onTap: () async {
                              if (!isSelected) {
                                await provider.selectApp(app, authProvider);
                              }
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 16), // Reduced bottom spacing
            ],
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing app switcher: $e');
    }
  }

  Widget _buildTabIcon(TabItem tab) {
    // Check if icon is a URL or Material icon name
    if (tab.icon.startsWith('http')) {
      return Image.network(
        tab.icon,
        width: 20, // Reduced size
        height: 20, // Reduced size
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.apps,
            size: 20, // Reduced size
            color: tab.iconColor != null 
              ? Color(int.parse('FF${tab.iconColor!.replaceAll('#', '')}', radix: 16))
              : Colors.blue,
          );
        },
      );
    } else {
      // Map Material icon names to Flutter icons
      IconData iconData;
      switch (tab.icon) {
        case 'Leaderboard':
          iconData = Icons.leaderboard;
          break;
        case 'AddLocation':
          iconData = Icons.add_location;
          break;
        case 'ContactEmergency':
          iconData = Icons.contact_emergency;
          break;
        case 'AddToPhotos':
          iconData = Icons.add_to_photos;
          break;
        case 'RequestQuote':
          iconData = Icons.request_quote;
          break;
        case 'Cases':
          iconData = Icons.cases;
          break;
        case 'PeopleAlt':
          iconData = Icons.people_alt;
          break;
        case 'EditLocation':
          iconData = Icons.edit_location;
          break;
        default:
          iconData = Icons.apps;
      }
      
      return Icon(
        iconData,
        size: 20, // Reduced size
        color: tab.iconColor != null 
          ? Color(int.parse('FF${tab.iconColor!.replaceAll('#', '')}', radix: 16))
          : Colors.blue,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA), // Light blue background
      appBar: AppBar(
        title: _isSearchActive
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search menu items...',
                    hintStyle: TextStyle(color: const Color.fromARGB(179, 159, 158, 158)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20),
                  ),
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: Colors.white,
                ),
              )
            : Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
        iconTheme: IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue[500], // Light blue color
        elevation: 2,
        actions: [
          if (!_isSearchActive) ...[
            IconButton(
              icon: Icon(Icons.refresh, size: 24),
              onPressed: _refreshApps,
              tooltip: 'Refresh',
            ),
          ],
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close : Icons.search, size: 24),
            onPressed: _onSearchPressed,
            tooltip: _isSearchActive ? 'Close Search' : 'Search',
          ),
          if (!_isSearchActive) ...[
            IconButton(
              icon: Icon(Icons.apps, size: 24), // Material UI Apps icon
              onPressed: _showAppSwitcher,
              tooltip: 'Switch App',
            ),
          ],
          SizedBox(width: 8), // Small padding from edge
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0), // Reduced padding
        child: Consumer<AppsProvider>(
          builder: (context, appsProvider, child) {
            print('📊 MenuScreen Consumer rebuild - isLoadingTabs=${appsProvider.isLoadingTabs}, tabsError=${appsProvider.tabsError}, appTabs=${appsProvider.appTabs.length}');

            // Show loading state for tabs
            if (appsProvider.isLoadingTabs) {
              return Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24), // Reduced padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF81D4FA)),
                        ),
                        SizedBox(height: 12), // Reduced spacing
                        Text(
                          'Loading ${appsProvider.selectedApp?.label ?? 'app'} items...',
                          style: TextStyle(fontSize: 14), // Reduced font size
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Show error state for tabs
            if (appsProvider.tabsError.isNotEmpty) {
              return Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24), // Reduced padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 40, color: Colors.red), // Reduced icon size
                        SizedBox(height: 12), // Reduced spacing
                        Text(
                          'Failed to load app items',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Reduced font size
                        ),
                        SizedBox(height: 6), // Reduced spacing
                        Text(
                          appsProvider.tabsError,
                          style: TextStyle(color: Colors.red, fontSize: 12), // Reduced font size
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12), // Reduced spacing
                        ElevatedButton(
                          onPressed: () {
                            print('🔄 Retry button pressed');
                            if (appsProvider.selectedApp != null) {
                              try {
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                appsProvider.fetchAppTabs(appsProvider.selectedApp!.name, authProvider);
                              } catch (e) {
                                print('❌ Error retrying: $e');
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF81D4FA),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Reduced padding
                          ),
                          child: Text('Retry', style: TextStyle(fontSize: 14)), // Reduced font size
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Get filtered tabs based on search query
            final filteredTabs = _getFilteredTabs(appsProvider.appTabs);

            // Show empty state (original tabs empty)
            if (appsProvider.appTabs.isEmpty) {
              return Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24), // Reduced padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 40, color: Colors.grey), // Reduced icon size
                        SizedBox(height: 12), // Reduced spacing
                        Text(
                          'No items available for ${appsProvider.selectedApp?.label ?? 'this app'}',
                          style: TextStyle(fontSize: 14), // Reduced font size
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12), // Reduced spacing
                        ElevatedButton(
                          onPressed: () {
                            print('🔄 Refresh button pressed (empty state)');
                            _refreshApps();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF81D4FA),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Reduced padding
                          ),
                          child: Text('Refresh', style: TextStyle(fontSize: 14)), // Reduced font size
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Show no search results state
            if (filteredTabs.isEmpty && _searchQuery.isNotEmpty) {
              return Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24), // Reduced padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 40, color: Colors.grey), // Reduced icon size
                        SizedBox(height: 12), // Reduced spacing
                        Text(
                          'No results found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Reduced font size
                        ),
                        SizedBox(height: 6), // Reduced spacing
                        Text(
                          'Try searching with different keywords',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12), // Reduced font size
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Show menu items in list format
            print('✅ Rendering ${filteredTabs.length} filtered menu items (${appsProvider.appTabs.length} total)');
            return Column(
              children: [
                // App info header - Reduced padding
                if (appsProvider.selectedApp != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
                    child: Row(
                      children: [
                        // Use backend image for app icon
                        Container(
                          width: 28, // Reduced size
                          height: 28, // Reduced size
                          decoration: BoxDecoration(
                            color: appsProvider.selectedApp!.color != null 
                              ? Color(int.parse('FF${appsProvider.selectedApp!.color!.replaceAll('#', '')}', radix: 16))
                              : Colors.blue,
                            borderRadius: BorderRadius.circular(6), // Reduced border radius
                          ),
                          child: appsProvider.selectedApp!.image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  appsProvider.selectedApp!.image!,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        appsProvider.selectedApp!.label.isNotEmpty ? appsProvider.selectedApp!.label[0].toUpperCase() : 'A',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Center(
                                child: Text(
                                  appsProvider.selectedApp!.label.isNotEmpty ? appsProvider.selectedApp!.label[0].toUpperCase() : 'A',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                        ),
                        SizedBox(width: 6), // Reduced spacing
                        Text(
                          appsProvider.selectedApp!.label,
                          style: TextStyle(
                            fontSize: 14, // Reduced font size
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Search results info - Reduced padding
                if (_searchQuery.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 14, color: Colors.grey[600]), // Reduced icon size
                        SizedBox(width: 6), // Reduced spacing
                        Text(
                          '${filteredTabs.length} results for "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 12, // Reduced font size
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Menu items list - Reduced margins
                Expanded(
                  child: Card(
                    margin: EdgeInsets.all(4), // Reduced margins
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.all(0),
                      itemCount: filteredTabs.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey[200],
                        indent: 12, // Reduced indent
                        endIndent: 12, // Reduced endIndent
                      ),
                      itemBuilder: (context, index) {
                        final tab = filteredTabs[index];
                        
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // Reduced padding
                          leading: Container(
                            width: 32, // Reduced size
                            height: 32, // Reduced size
                            decoration: BoxDecoration(
                              color: tab.iconColor != null 
                                ? Color(int.parse('FF${tab.iconColor!.replaceAll('#', '')}', radix: 16)).withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6), // Reduced border radius
                            ),
                            child: Center(
                              child: _buildTabIcon(tab),
                            ),
                          ),
                          title: Text(
                            tab.pluralLabel,
                            style: TextStyle(
                              fontSize: 14, // Reduced font size
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 14, // Reduced icon size
                            color: Colors.grey[400],
                          ),
                          // Update the onTap method in your MenuScreen's ListTile
                          onTap: () {
                            print('🔄 Navigating to ${tab.name} tab');
                            
                            // Get the current app's tabs to determine the correct screen types
                            final appsProvider = Provider.of<AppsProvider>(context, listen: false);
                            final currentAppTabs = appsProvider.appTabs;
                            
                            // Find the index of the selected tab in the current app's tabs
                            int tabIndex = currentAppTabs.indexWhere((appTab) => appTab.name == tab.name);
                            
                            int navigationIndex;
                            if (tabIndex == 0) {
                              // First tab -> navigate to index 1 (first dynamic screen)
                              navigationIndex = 1;
                            } else if (tabIndex == 1) {
                              // Second tab -> navigate to index 2 (second dynamic screen)
                              navigationIndex = 2;
                            } else {
                              // For tabs beyond the first two, navigate to the first dynamic screen
                              // and update it to show the selected tab type
                              navigationIndex = 1;
                            }
                            
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MainLayout(
                                  initialIndex: navigationIndex,
                                  screenType: tab.name, // Pass the specific tab name
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}