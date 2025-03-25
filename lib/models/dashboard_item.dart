class DashboardItem {
  final String id;
  final String name;
  final String type;
  final String dataSource;
  final Map<String, dynamic> data;
  final Map<String, dynamic> geometry;

  DashboardItem({
    required this.id,
    required this.name,
    required this.type,
    this.dataSource = '',
    required this.data,
    required this.geometry,
  });

  factory DashboardItem.fromJson(Map<String, dynamic> json) {
    return DashboardItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      dataSource: json['data_source']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic> ? json['data'] : {},
      geometry: json['geometry'] is Map<String, dynamic> ? json['geometry'] : {},
    );
  }

  // Getter for title to match your existing code
  String get title => name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'data_source': dataSource,
      'data': data,
      'geometry': geometry,
    };
  }
}

class Dashboard {
  final String id;
  final String name;
  final String createdBy;
  final String lastModifiedBy;
  final List<DashboardItem> items;

  Dashboard({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.lastModifiedBy,
    required this.items,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    // Extract dashboard info
    final dashboardData = json.containsKey('dashboard') ? json['dashboard'] : json;

    List<DashboardItem> items = [];

    // Extract components/items from the root level "components" array
    if (json.containsKey('components') && json['components'] is List) {
      items = (json['components'] as List)
          .map((item) => item is Map<String, dynamic>
          ? DashboardItem.fromJson(item)
          : null)
          .whereType<DashboardItem>() // Filter out null values
          .toList();
    }

    return Dashboard(
      id: dashboardData['id']?.toString() ?? '',
      name: dashboardData['name']?.toString() ?? '',
      createdBy: dashboardData['created_by']?.toString() ?? '',
      lastModifiedBy: dashboardData['last_modified_by']?.toString() ?? '',
      items: items,
    );
  }
}