import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../models/dashboard_item.dart';
import '../widgets/user_profile_widget.dart';
import 'list_screen.dart';
import 'menu_screen.dart';
import '../providers/tabs_provider.dart';
import '../providers/app_provider.dart';
class MainLayout extends StatefulWidget {
  final int initialIndex;
  final String? screenType;

  const MainLayout({super.key, this.initialIndex = 0, this.screenType});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  late int _currentIndex;
  late String _currentScreenType;
  List<String> _availableScreenTypes = [];
  
  // Store the ListScreen instances to prevent recreation
  Map<String, ListScreen> _listScreenCache = {};
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentScreenType = widget.screenType ?? 'leads'; // Default fallback
    print('🔧 MainLayout initState: initialIndex=${widget.initialIndex}, screenType=${widget.screenType}');
    WidgetsBinding.instance.addObserver(this);
    
    // Load tabs data when MainLayout initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTabsIfNeeded();
      _updateAvailableScreenTypesFromProvider();
    });
  }

  void _loadTabsIfNeeded() {
    if (!mounted) return;
    final tabsProvider = Provider.of<TabsProvider>(context, listen: false);
    if (tabsProvider.tabs.isEmpty && !tabsProvider.isLoading) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      tabsProvider.fetchTabs(authProvider);
    }
  }

  // Update available screen types from the current app's tabs
  void _updateAvailableScreenTypesFromProvider() {
    if (!mounted) return;
    
    final appsProvider = Provider.of<AppsProvider>(context, listen: false);
    
    if (appsProvider.appTabs.isNotEmpty) {
      // Get all tabs from the selected app
      final newScreenTypes = appsProvider.appTabs
          .map((tab) => tab.name)
          .toList();
      
      setState(() {
        _availableScreenTypes = newScreenTypes;
        _listScreenCache.clear(); // Clear cache when screen types change
        
        // Update current screen type if it's not in the new list or if it's still default
        if (newScreenTypes.isNotEmpty) {
          if (!newScreenTypes.contains(_currentScreenType) || _currentScreenType == 'leads') {
            _currentScreenType = newScreenTypes.first;
          }
        }
      });
      
      print('🔄 Updated available screen types: $_availableScreenTypes');
    }
  }

  // Get or create ListScreen for a specific type
  ListScreen _getListScreen(String type) {
    if (!_listScreenCache.containsKey(type)) {
      _listScreenCache[type] = ListScreen(
        key: ValueKey('list_screen_$type'),
        type: type,
      );
    }
    return _listScreenCache[type]!;
  }

  void navigateToTab(int index, {String? type}) {
    print('🔄 NavigateToTab called: index=$index, type=$type, currentType=$_currentScreenType');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentIndex = index;
          if (type != null) {
            _currentScreenType = type;
          }
        });
      }
    });
  }

  // Method to change the dynamic screen type (called when selecting different objects)
  void changeScreenType(String newType) {
    setState(() {
      _currentScreenType = newType;
      // If we're not currently on the dynamic tab, switch to it
      if (_currentIndex != 1) {
        _currentIndex = 1;
      }
    });
  }

  // Method to update available screen types when app is selected
  void updateAvailableScreenTypes(List<String> screenTypes) {
    setState(() {
      _availableScreenTypes = screenTypes;
      // Clear cache when screen types change
      _listScreenCache.clear();
      
      // Update current screen type if it's not in the new list
      if (_availableScreenTypes.isNotEmpty && !_availableScreenTypes.contains(_currentScreenType)) {
        _currentScreenType = _availableScreenTypes.first;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  String _getDisplayName(String? type, TabsProvider tabsProvider, AppsProvider appsProvider) {
    if (type == null) return 'Data';
    
    // First try to get display name from the current app's tabs
    try {
      final appTab = appsProvider.appTabs.firstWhere(
        (tab) => tab.name == type,
      );
      return appTab.pluralLabel;
    } catch (e) {
      // Tab not found, continue to fallback
    }
    
    // Fallback to TabsProvider if not found in app tabs
    if (!tabsProvider.isLoading && tabsProvider.tabs.isNotEmpty) {
      final displayName = tabsProvider.getDisplayNameForTab(type);
      if (displayName != type && displayName != type.toUpperCase()) {
        return displayName;
      }
    }
    
    return _getFallbackDisplayName(type);
  }

  String _getFallbackDisplayName(String type) {
    // Fallback to manual mapping if not found in tabs
    switch (type.toLowerCase()) {
      case 'leads':
        return 'Leads';
      case 'accounts':
        return 'Accounts';
      case 'contact':
        return 'Contacts';
      case 'opportunity':
        return 'Opportunities';
      case 'campaign':
        return 'Campaigns';
      case 'product':
        return 'Products';
      case 'quote':
        return 'Quotes';
      case 'campaign_member':
        return 'Campaign Members';
      case 'invoice':
        return 'Invoices';
      case 'visit':
        return 'Visits';
      case 'case':
        return 'Cases';
      case 'target':
        return 'Targets';
      default:
        return type.substring(0, 1).toUpperCase() + type.substring(1) + 's';
    }
  }

  IconData _getIconForType(String? type, TabsProvider tabsProvider, AppsProvider appsProvider) {
    if (type == null) return Icons.list;
    
    // First try to get icon from the current app's tabs
    try {
      final appTab = appsProvider.appTabs.firstWhere(
        (tab) => tab.name == type,
      );
      return _getIconFromString(appTab.icon);
    } catch (e) {
      // Tab not found, continue to fallback
    }
    
    // Fallback to TabsProvider
    if (!tabsProvider.isLoading && tabsProvider.tabs.isNotEmpty) {
      final tab = tabsProvider.getTabByName(type);
      
      if (tab != null && !tab.isIconUrl) {
        return _getIconFromString(tab.icon);
      }
    }
    
    return _getFallbackIcon(type);
  }

  // Helper method to convert icon string to IconData
  IconData _getIconFromString(String iconString) {
    switch (iconString.toLowerCase()) {
      case 'editlocation':
        return Icons.edit_location;
      case 'addlocation':
        return Icons.add_location;
      case 'cases':
        return Icons.work;
      case 'peoplealt':
        return Icons.people;
      case 'addtophotos':
        return Icons.add_to_photos;
      case 'requestquote':
        return Icons.request_quote;
      case 'contactemergency':
        return Icons.contact_emergency;
      case 'leaderboard':
        return Icons.leaderboard;
      default:
        return Icons.apps;
    }
  }

  IconData _getFallbackIcon(String type) {
    // Fallback to manual mapping
    switch (type.toLowerCase()) {
      case 'leads':
        return Icons.person;
      case 'accounts':
        return Icons.business;
      case 'contact':
        return Icons.contacts;
      case 'opportunity':
        return Icons.star;
      case 'campaign':
        return Icons.campaign;
      case 'product':
        return Icons.inventory;
      case 'quote':
        return Icons.request_quote;
      case 'campaign_member':
        return Icons.group;
      case 'invoice':
        return Icons.receipt;
      case 'visit':
        return Icons.location_on;
      case 'case':
        return Icons.work;
      case 'target':
        return Icons.track_changes;
      default:
        return Icons.list;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building MainLayout, currentIndex: $_currentIndex, screenType: $_currentScreenType');
    print('🔍 Available screen types: $_availableScreenTypes');

    return Consumer2<TabsProvider, AppsProvider>(
      builder: (context, tabsProvider, appsProvider, child) {
        // Update available screen types when app changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateAvailableScreenTypesFromProvider();
        });
        
        // Create screens list: Home + Dynamic Screen + Menu (3 total)
        final screens = <Widget>[
          // Index 0: Home
          const HomeScreenContent(),
          
          // Index 1: Dynamic screen (shows data based on _currentScreenType)
          _getListScreen(_currentScreenType),
          
          // Index 2: Menu
          MenuScreen(),
        ];

        // Build bottom navigation items: Home + Dynamic + Menu (3 total)
        final List<BottomNavigationBarItem> bottomNavItems = [
          // Home (Index 0)
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          
          // Dynamic item (Index 1) - changes based on selected object
          BottomNavigationBarItem(
            icon: Icon(_getIconForType(_currentScreenType, tabsProvider, appsProvider)),
            label: _getDisplayName(_currentScreenType, tabsProvider, appsProvider),
          ),
          
          // Menu (Index 2)
          const BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'Menu',
          ),
        ];

        print('📊 Bottom nav items count: ${bottomNavItems.length}');
        print('📋 Bottom nav labels: ${bottomNavItems.map((item) => item.label).toList()}');

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
          bottomNavigationBar: ClipRect(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Container(
                  height: 60,
                  child: Row(
                    children: List.generate(bottomNavItems.length, (index) {
                      final item = bottomNavItems[index];
                      final isSelected = _currentIndex == index;
                      
                      // Extract IconData from the BottomNavigationBarItem
                      IconData iconData;
                      
                      if (item.icon is Icon) {
                        iconData = (item.icon as Icon).icon!;
                      } else {
                        iconData = Icons.help; // fallback icon
                      }
                      
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            print('🔄 Bottom nav tapped: index=$index');
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iconData,
                                  color: isSelected ? Colors.blue : Colors.grey[600],
                                  size: 22,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label!,
                                  style: TextStyle(
                                    color: isSelected ? Colors.blue : Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
// Rest of your HomeScreenContent class remains the same...
class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  @override
  void initState() {
    super.initState();
    print('🏠 HomeScreen initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔄 Loading dashboard data...');
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
      dashboardProvider.initialize(authProvider);
    });
  }

  // All your existing chart building methods remain the same...
  Widget _buildWidget(DashboardItem item) {
    print('Building widget: ${item.title} (${item.type})');
    
    switch (item.type) {
      case 'chart':
        return _buildChartWidget(item);
      case 'list':
        return _buildListWidget(item);
      case 'stats':
        return _buildStatsWidget(item);
      default:
        return _buildStatsWidget(item);
    }
  }

  Widget _buildChartWidget(DashboardItem item) {
    final chartType = item.config['type'] as String?;
    final data = item.data;
    final labels = (data['labels'] as List?) ?? [];
    final values = (data['values'] as List?) ?? [];

    Widget chartWidget;
    switch (chartType?.toLowerCase()) {
      case 'pie_chart':
        chartWidget = _buildPieChart(labels, values);
        break;
      case 'line_chart':
        chartWidget = _buildLineChart(labels, values);
        break;
      case 'bar_chart':
        chartWidget = _buildBarChart(labels, values);
        break;
      default:
        chartWidget = Center(child: Text('Unsupported chart type: $chartType'));
    }

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(height: 200, child: chartWidget),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(List<dynamic> labels, List<dynamic> values) {
    return PieChart(
      PieChartData(
        sections: List.generate(
          labels.length,
          (index) => PieChartSectionData(
            value: (values[index] ?? 0).toDouble(),
            title: '${labels[index]}',
            radius: 100,
            titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<dynamic> labels, List<dynamic> values) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Text(labels[value.toInt()].toString());
                }
                return Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              values.length,
              (index) => FlSpot(index.toDouble(), (values[index] ?? 0).toDouble()),
            ),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<dynamic> labels, List<dynamic> values) {
    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Text(labels[value.toInt()].toString());
                }
                return Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        ),
        borderData: FlBorderData(show: true),
        barGroups: List.generate(
          values.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (values[index] ?? 0).toDouble(),
                color: Colors.blue,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListWidget(DashboardItem item) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Data Source: ${item.config['data_source'] ?? 'Unknown'}', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsWidget(DashboardItem item) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Data Source: ${item.config['data_source'] ?? 'Unknown'}', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building HomeScreen');
    return Column(
      children: [
        AppBar(
          title: Text('Home'),
          leading: const UserProfileWidget(),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                print('🔄 Refresh button pressed');
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
                dashboardProvider.refreshDashboard(authProvider);
              },
            ),
          ],
        ),
        Expanded(
          child: Container(
            color: Color(0xFFE0F7FA),
            child: Consumer<DashboardProvider>(
              builder: (context, dashboardProvider, child) {
                print('📊 Dashboard state: isLoading=${dashboardProvider.isLoading}, error=${dashboardProvider.error}, items=${dashboardProvider.items.length}');

                if (dashboardProvider.isLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading dashboard...'),
                      ],
                    ),
                  );
                }
                
                if (dashboardProvider.error.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dashboardProvider.error, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            print('🔄 Retrying dashboard load...');
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            dashboardProvider.refreshDashboard(authProvider);
                          },
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (dashboardProvider.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('No dashboard items available'),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            print('🔄 Refreshing empty dashboard...');
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            dashboardProvider.refreshDashboard(authProvider);
                          },
                          child: Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    print('🔄 Pull-to-refresh triggered');
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await dashboardProvider.refreshDashboard(authProvider);
                  },
                  child: ListView.builder(
                    itemCount: dashboardProvider.items.length,
                    itemBuilder: (context, index) {
                      final item = dashboardProvider.items[index];
                      print('📦 Building widget ${index + 1}: ${item.title} (${item.type})');
                      return _buildWidget(item);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}