import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../models/dashboard_item.dart';
import '../widgets/widget_factory.dart';
import 'list_screen.dart';
import 'menu_screen.dart';

class MainLayout extends StatefulWidget {
  final int initialIndex;
  final String? screenType;

  const MainLayout({Key? key, this.initialIndex = 0, this.screenType}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initializeScreens();
  }

  void _initializeScreens() {
    _screens = [
      const HomeScreen(),
      ListScreen(type: widget.screenType ?? 'lead'),
      ListScreen(type: 'account'),
      MenuScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Leads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    print('🏠 HomeScreen initialized');
    // Load dashboard when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔄 Loading dashboard data...');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
      dashboardProvider.initialize(authProvider);
    });
  }

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
        chartWidget = Center(
          child: Text('Unsupported chart type: $chartType'),
        );
    }

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: chartWidget,
            ),
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
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {

            if (pieTouchResponse?.touchedSection != null) {
              final section = pieTouchResponse!.touchedSection!;
              final index = section.touchedSectionIndex;
              if (index >= 0 && index < labels.length) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(labels[index].toString()),
                    content: Text('${values[index]} leads'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            }
          },
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
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
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
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blue.withOpacity(0.8),
            tooltipPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tooltipMargin: 0,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < labels.length) {
                  return LineTooltipItem(
                    '${values[index]} leads',
                    TextStyle(color: Colors.white),
                  );
                }
                return LineTooltipItem('', TextStyle(color: Colors.white));
              }).toList();
            },
          ),
        ),
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
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
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
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blue.withOpacity(0.8),
            tooltipPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tooltipMargin: 0,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex >= 0 && groupIndex < labels.length) {
                return BarTooltipItem(
                  '${values[groupIndex]} leads',
                  TextStyle(color: Colors.white),
                );
              }
              return BarTooltipItem('', TextStyle(color: Colors.white));
            },
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
            Text(
              item.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Data Source: ${item.config['data_source'] ?? 'Unknown'}',
              style: TextStyle(fontSize: 14),
            ),
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
            Text(
              item.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Data Source: ${item.config['data_source'] ?? 'Unknown'}',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building HomeScreen');
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA),
      appBar: AppBar(
        title: Text('Home'),
        automaticallyImplyLeading: false, // Remove back arrow
        backgroundColor: Colors.blue[700], // Lighter blue color
        foregroundColor: Colors.white, // Dark text for better contrast
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
        body: Consumer<DashboardProvider>(
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
                  Text(
                    dashboardProvider.error,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
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
    );
  }
}

// Wrapper to use MainLayout
class HomeScreenWrapper extends StatelessWidget {
  const HomeScreenWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MainLayout();
  }
}