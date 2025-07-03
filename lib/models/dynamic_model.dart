import 'dart:convert';

class ApiResponse {
  final ObjectInfo object;
  final ListViewInfo listview;
  final List<String> visibleColumns;
  final List<DynamicModel> data;
  final List<ColumnInfo> allColumns;
  final MetadataInfo metadata;

  ApiResponse({
    required this.object,
    required this.listview,
    required this.visibleColumns,
    required this.data,
    required this.allColumns,
    required this.metadata,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    // Extract visible columns and handle null values
    List<dynamic> rawVisibleColumns = [];
    if (json['visible_columns'] != null) {
      rawVisibleColumns = List<dynamic>.from(json['visible_columns']);
    }
    
    // Convert null values to empty strings to avoid issues later
    List<String> visibleColumns = rawVisibleColumns
        .map((column) => column?.toString() ?? '')
        .toList();

    // Convert data items to DynamicModel objects
    List<DynamicModel> data = [];
    if (json['data'] != null) {
      data = List<DynamicModel>.from(
          json['data'].map((item) => DynamicModel.fromJson(item, visibleColumns))
      );
    }

    // Extract column information
    List<ColumnInfo> allColumns = [];
    if (json['all_columns'] != null) {
      allColumns = List<ColumnInfo>.from(
          json['all_columns'].map((column) => ColumnInfo.fromJson(column))
      );
    }

    return ApiResponse(
      object: ObjectInfo.fromJson(json['object'] ?? {}),
      listview: ListViewInfo.fromJson(json['listview'] ?? {}),
      visibleColumns: visibleColumns,
      data: data,
      allColumns: allColumns,
      metadata: MetadataInfo.fromJson(json['metadata'] ?? {}),
    );
  }
}

class ObjectInfo {
  final String id;
  final String name;
  final String label;
  final String pluralLabel;

  ObjectInfo({
    required this.id,
    required this.name,
    required this.label,
    required this.pluralLabel,
  });

  factory ObjectInfo.fromJson(Map<String, dynamic> json) {
    return ObjectInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      pluralLabel: json['plural_label'] ?? '',
    );
  }
}

class ListViewInfo {
  final String id;
  final String label;
  final String name;

  ListViewInfo({
    required this.id,
    required this.label,
    required this.name,
  });

  factory ListViewInfo.fromJson(Map<String, dynamic> json) {
    return ListViewInfo(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class ColumnInfo {
  final String name;
  final String label;
  final String datatype;
  final bool required;
  final List<String> values; // Keep as List<String> for proper data structure

  ColumnInfo({
    required this.name,
    required this.label,
    required this.datatype,
    required this.required,
    required this.values,
  });

  // Convenience constructor for backward compatibility with String values
  ColumnInfo.withStringValues({
    required this.name,
    required this.label,
    required this.datatype,
    required this.required,
    required String stringValues,
  }) : values = stringValues.isEmpty ? [] : _parseStringValues(stringValues);

  // Helper method to parse string values into list
  static List<String> _parseStringValues(String stringValues) {
    if (stringValues.isEmpty) return [];
    
    // Handle JSON array format
    if (stringValues.startsWith('[')) {
      try {
        return List<String>.from(json.decode(stringValues));
      } catch (e) {
        // If JSON parsing fails, fall back to other methods
      }
    }
    
    // Handle comma-separated values
    if (stringValues.contains(',')) {
      return stringValues.split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    
    // Handle newline-separated values
    if (stringValues.contains('\n')) {
      return stringValues.split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    
    // Single value
    return [stringValues.trim()];
  }

  factory ColumnInfo.fromJson(Map<String, dynamic> json) {
    // Handle the values field properly
    List<String> valuesList = [];
    if (json['values'] != null) {
      if (json['values'] is List) {
        // If it's already a list, convert each item to string
        valuesList = (json['values'] as List)
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
      } else {
        // If it's a single value, parse it as string
        String stringValue = json['values'].toString();
        valuesList = _parseStringValues(stringValue);
      }
    }

    return ColumnInfo(
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      datatype: json['datatype'] ?? '',
      required: json['required'] ?? false,
      values: valuesList,
    );
  }

  // Helper method to check if this column has predefined values (like a picklist)
  bool get hasValues => values.isNotEmpty;

  // Helper method to get values as a comma-separated string (for backward compatibility)
  String get valuesAsString => values.join(', ');

  // Helper method for backward compatibility - parses values from column
  List<String> parseValues() {
    return values; // Already a list, just return it
  }
}

class MetadataInfo {
  final int total;
  final int limit;
  final int offset;

  MetadataInfo({
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory MetadataInfo.fromJson(Map<String, dynamic> json) {
    return MetadataInfo(
      total: json['total'] ?? 0,
      limit: json['limit'] ?? 0,
      offset: json['offset'] ?? 0,
    );
  }
}

// New class to represent relationship objects
class RelationshipObject {
  final String id;
  final String name;
  final Map<String, dynamic> additionalFields;

  RelationshipObject({
    required this.id,
    required this.name,
    this.additionalFields = const {},
  });

  factory RelationshipObject.fromJson(Map<String, dynamic> json) {
    // Extract id and name, put everything else in additionalFields
    Map<String, dynamic> additional = Map<String, dynamic>.from(json);
    additional.remove('id');
    additional.remove('name');

    return RelationshipObject(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      additionalFields: additional,
    );
  }

  @override
  String toString() => name.isNotEmpty ? name : id;
}

class DynamicModel {
  final String id;
  final Map<String, dynamic> attributes;
  final List<String> visibleColumns;

  DynamicModel({
    required this.id,
    required this.attributes,
    required this.visibleColumns,
  });

  factory DynamicModel.fromJson(Map<String, dynamic> json, List<String> visibleColumns) {
    return DynamicModel(
      id: json['id'] ?? '',
      attributes: Map<String, dynamic>.from(json),
      visibleColumns: visibleColumns,
    );
  }

  // Get any field safely
  dynamic getAttribute(String name) {
    return attributes[name];
  }

  // Get a string representation of a field, with a fallback value
  String getStringAttribute(String key, {String defaultValue = ''}) { 
    final value = attributes[key]; 
    if (value == null) return defaultValue; 
    
    // Handle relationship objects
    if (value is Map<String, dynamic>) {
      // If it's a relationship object, return the name field
      if (value.containsKey('name')) {
        return value['name']?.toString() ?? defaultValue;
      }
      // If no name field, try to return a meaningful representation
      return value.toString();
    }
    
    return value.toString(); 
  }

  // Get relationship object if the field is a relationship
  RelationshipObject? getRelationshipAttribute(String key) {
    final value = attributes[key];
    if (value is Map<String, dynamic>) {
      return RelationshipObject.fromJson(value);
    }
    return null;
  }

  // Get relationship ID - works for both old format (direct ID) and new format (object with ID)
  String? getRelationshipId(String key) {
    final value = attributes[key];
    if (value == null) return null;
    
    if (value is Map<String, dynamic>) {
      return value['id']?.toString();
    }
    
    return value.toString();
  }

  // Get relationship name - for display purposes
  String getRelationshipName(String key, {String defaultValue = ''}) {
    final value = attributes[key];
    if (value == null) return defaultValue;
    
    if (value is Map<String, dynamic>) {
      return value['name']?.toString() ?? defaultValue;
    }
    
    // If it's just an ID, return the ID as fallback
    return value.toString();
  }

  // Enhanced method to get display value for any field with special handling for _id fields
  String getDisplayValue(String key, {String defaultValue = ''}) {
    final value = attributes[key];
    
    // Special handling for fields ending with _id
    if (key.endsWith('_id')) {
      // Try to find the corresponding relationship object
      String relationshipKey = key.substring(0, key.length - 3); // Remove '_id' suffix
      
      // Check if we have a relationship object for this field
      if (attributes.containsKey(relationshipKey)) {
        final relationshipValue = attributes[relationshipKey];
        if (relationshipValue is Map<String, dynamic>) {
          // If the relationship object has a name, use it
          if (relationshipValue.containsKey('name') && relationshipValue['name'] != null) {
            String name = relationshipValue['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              return name;
            }
          }
          // If no name but has id, use the id
          if (relationshipValue.containsKey('id') && relationshipValue['id'] != null) {
            return relationshipValue['id']?.toString() ?? defaultValue;
          }
        }
      }
      
      // If no relationship object found or it's null, show the ID value if available
      if (value != null) {
        return value.toString();
      }
      
      return defaultValue;
    }
    
    // Regular handling for non-_id fields
    if (value == null) return defaultValue;
    
    // Handle relationship objects - show the name
    if (value is Map<String, dynamic>) {
      if (value.containsKey('name')) {
        return value['name']?.toString() ?? defaultValue;
      }
      // For other objects, try to find a meaningful display value
      if (value.containsKey('label')) {
        return value['label']?.toString() ?? defaultValue;
      }
      if (value.containsKey('title')) {
        return value['title']?.toString() ?? defaultValue;
      }
      // Last resort - return the id if available
      if (value.containsKey('id')) {
        return value['id']?.toString() ?? defaultValue;
      }
    }
    
    // Handle arrays
    if (value is List) {
      return value.join(', ');
    }
    
    // Handle dates
    if (value is String && _isDateString(value)) {
      return _formatDate(value);
    }
    
    return value.toString();
  }

  // Helper method to check if a string looks like a date
  bool _isDateString(String value) {
    // Check for ISO date format
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}');
    return dateRegex.hasMatch(value);
  }

  // Helper method to format dates
  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  // Get a mapping of visible attributes only
  Map<String, dynamic> getVisibleAttributes() {
    Map<String, dynamic> result = {};
    for (String column in visibleColumns) {
      // Skip empty column names
      if (column.isEmpty) continue;
      
      if (attributes.containsKey(column)) {
        result[column] = attributes[column];
      }
    }
    return result;
  }

  // Method to check if a field is a relationship field
  bool isRelationshipField(String key) {
    final value = attributes[key];
    return value is Map<String, dynamic> && value.containsKey('id');
  }

  // Get all relationship fields
  Map<String, RelationshipObject> getRelationshipFields() {
    Map<String, RelationshipObject> relationships = {};
    
    attributes.forEach((key, value) {
      if (value is Map<String, dynamic> && value.containsKey('id')) {
        relationships[key] = RelationshipObject.fromJson(value);
      }
    });
    
    return relationships;
  }

  // Debug method to log field values - enhanced for _id fields
  void debugLogField(String key) {
    final value = attributes[key];
    print('🔍 Field "$key": Type=${value.runtimeType}, Value=$value');
    
    if (key.endsWith('_id')) {
      String relationshipKey = key.substring(0, key.length - 3);
      print('🔗 Looking for relationship field: "$relationshipKey"');
      
      if (attributes.containsKey(relationshipKey)) {
        final relationshipValue = attributes[relationshipKey];
        print('🔗 Found relationship: Type=${relationshipValue.runtimeType}, Value=$relationshipValue');
        if (relationshipValue is Map<String, dynamic>) {
          print('🔗 Relationship keys: ${relationshipValue.keys.toList()}');
          if (relationshipValue.containsKey('name')) {
            print('🔗 Relationship name: ${relationshipValue['name']}');
          }
        }
      } else {
        print('🔗 No relationship field found for "$relationshipKey"');
      }
    }
    
    if (value is Map<String, dynamic>) {
      print('🔍 Object keys: ${value.keys.toList()}');
      if (value.containsKey('name')) print('🔍 Name field: ${value['name']}');
      if (value.containsKey('id')) print('🔍 ID field: ${value['id']}');
    }
  }
}