// dashboard_model.dart
class DashboardItem {
  final String id;
  final String title;
  final String type;
  final int row;
  final int column;
  final double width;
  final double height;
  final Map<String, dynamic>? data;

  DashboardItem({
    required this.id,
    required this.title,
    required this.type,
    required this.row,
    required this.column,
    this.width = 0.5,
    this.height = 0.3,
    this.data,
  });

  factory DashboardItem.fromJson(Map<String, dynamic> json) {
    return DashboardItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      row: json['row'] ?? 0,
      column: json['column'] ?? 0,
      width: (json['width'] ?? 0.5).toDouble(),
      height: (json['height'] ?? 0.3).toDouble(),
      data: json['data'],
    );
  }
}
