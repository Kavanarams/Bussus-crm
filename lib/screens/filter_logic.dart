import '../providers/data_provider.dart';

/// Class to represent column information
class ColumnInfo {
  final String name;
  final String type;
  final String label;
  final bool display;
  
  ColumnInfo({
    required this.name,
    required this.type,
    required this.label,
    required this.display,
  });
}

/// Represents a single filter condition
class FilterCondition {
  String field;
  FilterOperator operator;
  String value;
  
  FilterCondition({
    required this.field,
    required this.operator,
    required this.value,
  });
  
  @override
  String toString() {
    return '$field ${operator.apiValue} $value';
  }
  
  // Convert to a format your API might expect
  Map<String, dynamic> toApiFormat() {
    return {
      'field': field,
      'operator': operator.apiValue,
      'value': value,
    };
  }
}

/// Function to get operators based on field type
List<FilterOperator> getOperatorsForFieldType(String type) {
  switch (type.toLowerCase()) {
    case 'text':
      return [
        FilterOperator.equals,
        FilterOperator.notEquals,
        FilterOperator.contains,
        FilterOperator.notContains,
        FilterOperator.greaterThan,
        FilterOperator.greaterThanOrEqual,
        FilterOperator.lessThan,
        FilterOperator.lessThanOrEqual,
        FilterOperator.startsWith
      ];
    case 'select':
      return [FilterOperator.equals, FilterOperator.notEquals];
    case 'date':
    case 'datetime':
      return [
        FilterOperator.before,
        FilterOperator.after,
        FilterOperator.equals,
        FilterOperator.notEquals
      ];
    case 'number':
      return [
        FilterOperator.equals,
        FilterOperator.notEquals,
        FilterOperator.contains,
        FilterOperator.notContains,
        FilterOperator.greaterThan,
        FilterOperator.greaterThanOrEqual,
        FilterOperator.lessThan,
        FilterOperator.lessThanOrEqual,
        FilterOperator.startsWith
      ];
    case 'multi_select':
      return [FilterOperator.contains, FilterOperator.notContains];
    case 'boolean':
      return [FilterOperator.equals];
    case 'picklist':
      return [
        FilterOperator.equals,
        FilterOperator.notEquals,
        FilterOperator.contains,
        FilterOperator.notContains,
        FilterOperator.greaterThan,
        FilterOperator.greaterThanOrEqual,
        FilterOperator.lessThan,
        FilterOperator.lessThanOrEqual,
        FilterOperator.startsWith
      ];
    default:
      return [
        FilterOperator.equals,
        FilterOperator.notEquals,
        FilterOperator.contains,
        FilterOperator.notContains,
        FilterOperator.greaterThan,
        FilterOperator.greaterThanOrEqual,
        FilterOperator.lessThan,
        FilterOperator.lessThanOrEqual,
        FilterOperator.startsWith
      ];
  }
}

/// Use this class to manage filter logic and convert to format needed by API
class FilterManager {
  // Convert active filters to the format your API expects
  static List<Map<String, dynamic>> toApiQuery(List<FilterCondition> activeFilters) {
    List<Map<String, dynamic>> filtersList = [];
    
    for (var filter in activeFilters) {
      filtersList.add({
        'field': filter.field,
        'operator': filter.operator.apiValue,
        'value': filter.value
      });
    }
    
    return filtersList;
  }
  
  // Convert from the current format in your data provider to FilterCondition objects
  static List<FilterCondition> fromCurrentFilters(Map<String, String> currentFilters) {
    List<FilterCondition> conditions = [];
    
    currentFilters.forEach((field, value) {
      if (value.contains(':')) {
        // Handle value in "operator:value" format
        List<String> parts = value.split(':');
        String operator = parts[0];
        String filterValue = parts.sublist(1).join(':');
        
        // Convert API operator string to FilterOperator enum
        FilterOperator filterOperator = FilterOperator.fromString(operator);
        
        conditions.add(FilterCondition(
          field: field,
          operator: filterOperator,
          value: filterValue,
        ));
      } else {
        // Default to equals if no operator specified
        conditions.add(FilterCondition(
          field: field,
          operator: FilterOperator.equals,
          value: value,
        ));
      }
    });
    
    return conditions;
  }
  
  // Convert FilterCondition list back to the format your API expects
  static Map<String, String> toSimpleFilters(List<FilterCondition> conditions) {
    Map<String, String> apiFilters = {};
    
    for (var condition in conditions) {
      // Convert to "operator:value" format
      apiFilters[condition.field] = "${condition.operator.apiValue}:${condition.value}";
    }
    
    return apiFilters;
  }
}