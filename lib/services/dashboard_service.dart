import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/dashboard_item.dart';
import '../providers/auth_provider.dart';

class DashboardService {
  final String apiUrl = 'https://qa.api.bussus.com/v2/api/setup/dashboard';
  final AuthProvider authProvider;

  DashboardService({required this.authProvider});

  Future<Dashboard> fetchDashboard() async {
    try {
      // Get token from your AuthProvider
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token is missing');
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final String responseBody = response.body;

        Map<String, dynamic> data;
        try {
          data = json.decode(responseBody);

          // Debug the structure
          print('JSON contains dashboard key: ${data.containsKey('dashboard')}');
          print('JSON contains components key: ${data.containsKey('components')}');

          if (data.containsKey('components')) {
            print('Components is a list: ${data['components'] is List}');
            print('Number of components: ${data['components'] is List ? (data['components'] as List).length : 0}');
            if (data['components'] is List) {
              final components = data['components'] as List;
              if (components.isNotEmpty && components[0] is Map) {
                print('First component structure: ${components[0]}');
              }
            }
          }
        } catch (e) {
          print('JSON decode error: $e');
          throw Exception('Invalid JSON response from server');
        }

        // Create dashboard from parsed data
        final dashboard = Dashboard.fromJson(data);

        // Debug: print parsed items
        print('Parsed ${dashboard.items.length} dashboard items');
        for (var item in dashboard.items) {
          print('Item: ${item.id} - ${item.name} (${item.type})');
        }

        return dashboard;
      } else if (response.statusCode == 401) {
        print('401 Unauthorized response body: ${response.body}');
        throw Exception('Unauthorized: Please login again');
      } else {
        print('Error response body: ${response.body}');
        throw Exception('Failed to load dashboard: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception caught in fetchDashboard: $e');
      throw Exception('Error fetching dashboard: $e');
    }
  }
}