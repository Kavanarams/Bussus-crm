class DashboardItem {
  final String id;
  final String type;
  final String title;
  final String name;
  final Map<String, dynamic> config;
  final Map<String, dynamic> data;
  final int order;
  final bool isActive;

  DashboardItem({
    required this.id,
    required this.type,
    required this.title,
    required this.name,
    required this.config,
    required this.data,
    required this.order,
    required this.isActive,
  });

  factory DashboardItem.fromJson(Map<String, dynamic> json) {
    return DashboardItem(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      name: json['name'] ?? json['title'] ?? '',
      config: json['config'] ?? {},
      data: json['data'] ?? {},
      order: json['order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'name': name,
      'config': config,
      'data': data,
      'order': order,
      'is_active': isActive,
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