import 'package:flutter/material.dart';
import 'list_screen.dart';
import 'home_screen.dart';

class MenuScreen extends StatelessWidget {
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
                    // Instead of popping and pushing, replace the current screen
                    // in the navigation stack with the appropriate ListScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainLayout(initialIndex: 1, screenType: 'lead'),
                      ),
                    );
                  }
              ),
              Divider(height: 1, thickness: 1),
              _buildListItem(
                  context,
                  'Accounts',
                      () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainLayout(initialIndex: 1, screenType: 'account'),
                      ),
                    );
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
    return InkWell(
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
    );
  }
}