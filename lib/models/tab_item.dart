class TabItem {
  final String id;
  final String name;
  final String label;
  final String pluralLabel;
  final String icon;
  final String? iconColor;

  TabItem({
    required this.id,
    required this.name,
    required this.label,
    required this.pluralLabel,
    required this.icon,
    this.iconColor,
  });

  factory TabItem.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 Parsing TabItem from JSON: $json');
      
      // Handle different possible JSON structures
      Map<String, dynamic> object;
      
      if (json.containsKey('object') && json['object'] is Map<String, dynamic>) {
        object = json['object'] as Map<String, dynamic>;
      } else {
        // If there's no 'object' key, assume the json itself contains the data
        object = json;
      }
      
      final tabItem = TabItem(
        id: _getStringValue(json, 'id', 'unknown_id'),
        name: _getStringValue(object, 'name', 'unknown_name'),
        label: _getStringValue(object, 'label', 'Unknown'),
        pluralLabel: _getStringValue(object, 'plural_label', 'Unknown Items'),
        icon: _getStringValue(object, 'icon', 'list'),
        iconColor: _getOptionalStringValue(object, 'icon_color'),
      );
      
      print('✅ Successfully parsed TabItem: ${tabItem.toString()}');
      return tabItem;
    } catch (e) {
      print('❌ Error parsing TabItem from JSON: $e');
      print('❌ JSON data: $json');
      
      // Return a fallback TabItem to prevent crashes
      return TabItem(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        name: 'error_item',
        label: 'Error Item',
        pluralLabel: 'Error Items',
        icon: 'error',
        iconColor: '#FF0000',
      );
    }
  }

  // Helper method to safely get string values
  static String _getStringValue(Map<String, dynamic> map, String key, String defaultValue) {
    final value = map[key];
    if (value == null) {
      print('⚠️ Missing required field: $key, using default: $defaultValue');
      return defaultValue;
    }
    return value.toString();
  }

  // Helper method to safely get optional string values
  static String? _getOptionalStringValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    return value?.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': {
        'name': name,
        'label': label,
        'plural_label': pluralLabel,
        'icon': icon,
        'icon_color': iconColor,
      },
    };
  }

  // Helper method to check if icon is a URL
  bool get isIconUrl => icon.startsWith('http');

  // Helper method to get Flutter IconData from Material icon name
  String get flutterIconName {
    switch (icon.toLowerCase()) {
      case 'editlocation':
        return 'edit_location';
      case 'addlocation':
        return 'add_location';
      case 'cases':
        return 'work';
      case 'peoplealt':
        return 'people';
      case 'addtophotos':
        return 'add_to_photos';
      case 'requestquote':
        return 'request_quote';
      case 'contactemergency':
        return 'contact_emergency';
      case 'leaderboard':
        return 'leaderboard';
      default:
        return 'list';
    }
  }

  @override
  String toString() {
    return 'TabItem(id: $id, name: $name, label: $label, pluralLabel: $pluralLabel, icon: $icon, iconColor: $iconColor)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TabItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}