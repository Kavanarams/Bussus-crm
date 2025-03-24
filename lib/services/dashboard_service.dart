
// dashboard_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:materio/models/dashboard_model.dart';

class DashboardService {
  static const String apiUrl = 'http://88.222.241.78/v2/api/setup/dashboard';

  Future<List<DashboardItem>> fetchDashboard() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['data'] != null && jsonData['data'] is List) {
          return (jsonData['data'] as List)
              .map((item) => DashboardItem.fromJson(item))
              .toList();
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to load dashboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching dashboard data: $e');
    }
  }
}