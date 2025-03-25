// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/widget_factory.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Safely schedule initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  void _initializeDashboard() {
    if (!_isInitialized) {
      // Get providers
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

      // Initialize dashboard provider with auth provider
      dashboardProvider.initialize(authProvider);

      // Fetch dashboard data
      dashboardProvider.fetchDashboard();

      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        // Keep any existing app bar actions here
      ),
      // Keep your existing drawer if you have one
      body: Consumer<DashboardProvider>(
        builder: (context, dashboardProvider, child) {
          if (dashboardProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (dashboardProvider.error.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${dashboardProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => dashboardProvider.fetchDashboard(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (dashboardProvider.items.isEmpty) {
            return const Center(
              child: Text('No dashboard items available'),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: dashboardProvider.items.length,
            onReorder: dashboardProvider.reorderItems,
            itemBuilder: (context, index) {
              final item = dashboardProvider.items[index];
              return Padding(
                key: Key(item.id),
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: WidgetFactory.buildWidget(item),
              );
            },
          );
        },
      ),
      // Keep any existing bottom navigation bar here
    );
  }
}