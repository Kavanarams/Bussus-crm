import 'package:flutter/material.dart';
import 'list_screen.dart';
import 'home_screen.dart';
import 'package:provider/provider.dart';
import 'package:materio/providers/data_provider.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA), // Light blue background
      appBar: AppBar(
        title: Text(
          'Menu',
          style: TextStyle(color: Colors.white), // White text color
        ),
        iconTheme: IconThemeData(color: Colors.white), // White icon color
        automaticallyImplyLeading: false, // Remove back button since we're using bottom nav
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildListItem(
                  context,
                  'Leads',
                      () {
                    // Clear any existing data before navigation
                    final dataProvider = Provider.of<DataProvider>(context, listen: false);
                    dataProvider.clearFilters();

                    // Use the global key to access the main layout
                    if (mainLayoutKey.currentState != null) {
                      mainLayoutKey.currentState!.navigateToTab(1, type: 'lead');
                    } else {
                      // Fallback if for some reason the key isn't available
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainLayout(initialIndex: 1, screenType: 'lead'),
                        ),
                      );
                    }
                  }
              ),
              Divider(height: 1, thickness: 1),
              _buildListItem(
                  context,
                  'Accounts',
                      () {
                    // Clear any existing data before navigation
                    final dataProvider = Provider.of<DataProvider>(context, listen: false);
                    dataProvider.clearFilters();

                    // Use the global key to access the main layout
                    if (mainLayoutKey.currentState != null) {
                      mainLayoutKey.currentState!.navigateToTab(2, type: 'account');
                    } else {
                      // Fallback if for some reason the key isn't available
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainLayout(initialIndex: 2, screenType: 'account'),
                        ),
                      );
                    }
                  }
              ),

              Divider(height: 1, thickness: 1),
              _buildListItem(
                  context,
                  'Invoices',
                      () {
                    // This can navigate to the existing Invoices tab
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainLayout(initialIndex: 2),
                      ),
                    );
                  }
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildListItem(BuildContext context, String title, VoidCallback onTap) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}