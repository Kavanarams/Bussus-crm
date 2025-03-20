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
    // Extract visible columns
    List<String> visibleColumns = List<String>.from(json['visible_columns'] ?? []);

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
  final String values;

  ColumnInfo({
    required this.name,
    required this.label,
    required this.datatype,
    required this.required,
    required this.values,
  });

  factory ColumnInfo.fromJson(Map<String, dynamic> json) {
    return ColumnInfo(
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      datatype: json['datatype'] ?? '',
      required: json['required'] ?? false,
      values: json['values'] ?? '',
    );
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
  String getStringAttribute(String name, {String defaultValue = ''}) {
    dynamic value = attributes[name];
    return value != null ? value.toString() : defaultValue;
  }

  // Get a mapping of visible attributes only
  Map<String, dynamic> getVisibleAttributes() {
    Map<String, dynamic> result = {};
    for (String column in visibleColumns) {
      if (attributes.containsKey(column)) {
        result[column] = attributes[column];
      }
    }
    return result;
  }
}