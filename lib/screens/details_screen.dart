import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_button_styles.dart';
import 'edit_screen.dart';
import 'newtask.dart';
import 'AllActivitiesScreen.dart';

class DetailsScreen extends StatefulWidget {
  final String type;
  final String itemId;

  const DetailsScreen({
    super.key,
    required this.type,
    required this.itemId,
  });

  @override
  _DetailsScreenState createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _details = {};
  List<ColumnInfo> _allColumns = [];
  List<String> _visibleColumns = [];
  String? _error;
  List<Map<String, dynamic>> _layoutSections = [];
  List<Map<String, dynamic>> _activities = [];
  final bool _isLoadingActivities = false;
  bool _activitiesSectionExpanded = false;
  
  // Map to keep track of expanded sections - the key is the section title
  final Map<String, bool> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      
      // Fetch details using DataProvider
      final result = await dataProvider.fetchItemDetails(widget.type, widget.itemId);
      
      // Process the result
      _details = result['data'] ?? {};
      _allColumns = _extractColumns(result['all_columns'] ?? []);
      _visibleColumns = List<String>.from(result['visible_columns'] ?? []);

      // Handle layout sections as a list
      if (result['layout'] != null && result['layout']['sections'] != null) {
        var sections = result['layout']['sections'];
        if (sections is List) {
          _layoutSections = List<Map<String, dynamic>>.from(sections.map((section) =>
            Map<String, dynamic>.from(section)
          ));
          
          // Initialize all sections as collapsed by default
          for (var section in _layoutSections) {
            String title = section['title'] ?? 'Details';
            _expandedSections[title] = false;
          }
          
          // If there's a default section and no layout sections, initialize that too
          if (_layoutSections.isEmpty) {
            _expandedSections['Details'] = false;
          }
        }
      }

      // Load activities from the tasks field
      if (result['tasks'] != null) {
        _activities = List<Map<String, dynamic>>.from(result['tasks']);
        print('📊 Loaded ${_activities.length} activities from preview response');
      }

      print('📊 Loaded details with ${_details.length} fields');
      print('📊 Visible columns: $_visibleColumns');
      print('📊 Layout sections: ${_layoutSections.length}');
      
      // Handle error from DataProvider
      if (dataProvider.error != null) {
        setState(() {
          _error = dataProvider.error;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error occurred: $e';
      });
      print('❌ Error processing details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ColumnInfo> _extractColumns(List<dynamic> columns) {
    return columns.map((column) => ColumnInfo.fromJson(column)).toList();
  }

  String _getFieldLabel(String fieldName) {
    for (var column in _allColumns) {
      if (column.name == fieldName) {
        return column.label;
      }
    }
    return fieldName;
  }

  bool _isFieldRequired(String fieldName) {
    for (var column in _allColumns) {
      if (column.name == fieldName) {
        return column.required;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(AppDimensions.appBarHeight),
        child: AppBar(
          title: Text(
            "${widget.type.substring(0, 1).toUpperCase()}${widget.type.substring(1)} Details",
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {}
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {}
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: AppTextStyles.bodyMedium))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  // Use consistent container for all sections
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingL, 
                      vertical: AppDimensions.spacingS
                    ),
                    child: Column(
                      children: [
                        // Layout sections with consistent styling
                        ..._layoutSections.isNotEmpty
                            ? _layoutSections.map((section) {
                                return _buildExpandableSection(section);
                              }).toList()
                            : [_buildExpandableDefaultSection()],
                        // Activities section with consistent styling
                        _buildActivitiesSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeaderInfo() {
    // Get the title (Mr, Mrs, etc.) if available
    String title = _details['title'] ?? '';

    // Get the name of the item
    String name = _details['name'] ?? 'Unknown';

    // Capitalize the first letter of title and name
    if (title.isNotEmpty) {
      title = title.substring(0, 1).toUpperCase() + title.substring(1).toLowerCase();
    }

    // If name contains multiple words, capitalize each word
    List<String> nameParts = name.split(' ');
    String capitalizedName = nameParts.map((part) {
      if (part.isNotEmpty) {
        return part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase();
      }
      return part;
    }).join(' ');

    // Combine title and name if title exists
    String displayName = title.isNotEmpty ? "$title $capitalizedName" : capitalizedName;

    // First get the capitalized object type
    String objectType = widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1).toLowerCase();

    return Container(
      color: AppColors.cardBackground,
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL, 
        vertical: AppDimensions.spacingL
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with action icons - positioned at the top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Edit Icon (Pencil)
              _buildActionButton(
                Icons.edit,
                'Edit',
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditItemScreen(
                        type: widget.type,
                        itemId: widget.itemId,
                      ),
                    ),
                  );
                  if (result == true) {
                    Navigator.pop(context, true); // Refresh the list screen
                  }
                },
              ),

              // Delete Icon
              _buildActionButton(
                Icons.delete,
                'Delete',
                () async {
                  await _handleDelete();
                },
              ),

              // Task Icon (New/Add Activity)
              _buildActionButton(
                Icons.task_alt,
                'Task',
                () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskFormScreen(
                        relatedObjectId: widget.itemId,
                        relatedObjectType: widget.type,
                        relatedObjectName: _details['name'],
                      ),
                    ),
                  );
                  
                  // If task was successfully created, reload details
                  if (result == true) {
                    _loadDetails();
                  }
                },
              ),

              // More Icon
              _buildActionButton(
                Icons.more_horiz,
                'More',
                () {
                  // Add more functionality here
                },
              ),
            ],
          ),

          // Add some spacing between icons and text
          SizedBox(height: AppDimensions.spacingL),

          // Object type (Lead, Account, etc.)
          Text(
            objectType,
            style: AppTextStyles.secondaryText,
          ),

          // Name with title
          Text(
            displayName,
            style: AppTextStyles.heading,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: AppDimensions.circleRadius,
          backgroundColor: AppColors.actionButtonBackground,
          child: IconButton(
            icon: Icon(icon, color: AppColors.primary, size: AppDimensions.iconS),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: AppDimensions.spacingXs),
        Text(label, style: AppTextStyles.smallActionText),
      ],
    );
  }
  
  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        ),
        title: Text('Confirm Delete', style: AppTextStyles.subheading),
        content: Text('Are you sure you want to delete this item?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppButtonStyles.dialogCancelButton,
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.dialogConfirmButton,
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final success = await dataProvider.deleteItem(widget.type, widget.itemId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dataProvider.error ?? 'Failed to delete item'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildExpandableSection(Map<String, dynamic> section) {
    final title = section['title'] ?? 'Details';
    final fields = List<String>.from(section['fields'] ?? []);
    final isExpanded = _expandedSections[title] ?? false;

    return Card(
      margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Column(
        children: [
          // Clickable header with arrow
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[title] = !isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle,
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: AppDimensions.iconL,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...fields.map<Widget>((fieldName) {
                    if (!_details.containsKey(fieldName)) return const SizedBox();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem(
                            _getFieldLabel(fieldName),
                            _formatValue(_details[fieldName]),
                            _isFieldRequired(fieldName)
                        ),
                        const Divider(),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandableDefaultSection() {
    final isExpanded = _expandedSections['Details'] ?? false;
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Column(
        children: [
          // Clickable header with arrow
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections['Details'] = !isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Details',
                    style: AppTextStyles.cardTitle,
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: AppDimensions.iconL,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._details.entries.map<Widget>((entry) {
                    if (!_visibleColumns.contains(entry.key) || entry.key == 'id') {
                      return const SizedBox();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoItem(
                            _getFieldLabel(entry.key),
                            _formatValue(entry.value),
                            _isFieldRequired(entry.key)
                        ),
                        const Divider(),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoItem(String title, String value, bool required) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              "$title${required ? ' *' : ''}",
              style: AppTextStyles.fieldLabel
          ),
          Text(
              value,
              style: AppTextStyles.fieldValue
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';

    if (value is bool) {
      return value ? 'Yes' : 'No';
    } else if (value is Map) {
      return value.isEmpty ? 'N/A' : value.toString();
    } else if (value is List) {
      return value.isEmpty ? 'N/A' : value.join(', ');
    } else {
      return value.toString().isEmpty ? 'N/A' : value.toString();
    }
  }

  Widget _buildActivitiesSection() {
    // Count open activities (not completed)
    int activitiesCount = _activities.length;
    // Limit the number of tasks to show in preview
    final tasksToShow = _activitiesSectionExpanded ? 
        (_activities.length > 2 ? 2 : _activities.length) : 0;
    final hasMoreTasks = _activities.length > 2;
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Column(
        children: [
          // Header with expand/collapse functionality
          InkWell(
            onTap: () {
              setState(() {
                _activitiesSectionExpanded = !_activitiesSectionExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Open Activities',
                        style: AppTextStyles.cardTitle,
                      ),
                      SizedBox(width: AppDimensions.spacingS),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingS, 
                          vertical: AppDimensions.spacingXs
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.statusBadgeBg,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                        ),
                        child: Text(
                          '$activitiesCount',
                          style: TextStyle(
                            color: AppColors.statusBadgeText,
                            fontWeight: FontWeight.bold,
                            fontSize: AppDimensions.textS,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _activitiesSectionExpanded 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: AppDimensions.iconL,
                  ),
                ],
              ),
            ),
          ),
          
          // Activities list - only visible when expanded, limited to 2 items
          if (_activitiesSectionExpanded) ...[
            Divider(height: 1),
            _isLoadingActivities
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingL),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _activities.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(AppDimensions.spacingL),
                        child: Text(
                          'No activities found',
                          style: AppTextStyles.secondaryText,
                        ),
                      )
                    : Column(
                        children: [
                          ListView.separated(
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: tasksToShow,
                            separatorBuilder: (context, index) => Divider(height: 1),
                            itemBuilder: (context, index) {
                              final activity = _activities[index];
                              return _buildActivityItem(activity);
                            },
                          ),
                          
                          // Add "View More" button if there are more than 2 activities
                          if (hasMoreTasks) ...[
                            Divider(height: 1),
                            // In the View All activities button
                              InkWell(
                                onTap: () async {
                                  // Navigate to the all activities screen
                                  final result = await Navigator.push(
                                    context, 
                                    MaterialPageRoute(
                                      builder: (context) => AllActivitiesScreen(
                                        activities: _activities, 
                                        objectType: widget.type,
                                        objectName: _details['name'] ?? 'Unknown',
                                      ),
                                    ),
                                  );
                                  
                                  // If result is true, reload details to refresh the activities list
                                  if (result == true) {
                                    _loadDetails();
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingL),
                                  child: Center(
                                    child: Text(
                                      'View All Activities',
                                      style: AppTextStyles.actionText,
                                    ),
                                  ),
                                ),
                              ),  
                          ],
                        ],
                      ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL, 
        vertical: AppDimensions.spacingXs
      ),
      title: Text(
        activity['subject'] ?? 'No Subject',
        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppDimensions.spacingXs),
          Row(
            children: [
              Text(
                'Due Date: ',
                style: AppTextStyles.labelText,
              ),
              Text(
                '${activity['due_date'] ?? 'N/A'}',
                style: AppTextStyles.fieldValue,
              ),
            ],
          ),
          SizedBox(height: AppDimensions.spacingXxs),
          Row(
            children: [
              Text(
                'Status: ',
                style: AppTextStyles.labelText,
              ),
              Text(
                '${activity['status'] ?? 'N/A'}',
                style: AppTextStyles.fieldValue,
              ),
            ],
          ),
        ],
      ),
      
      trailing: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingL, 
          vertical: AppDimensions.spacingXs
        ),
        decoration: BoxDecoration(
          color: _getStatusColor(activity['status']),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        child: Text(
          activity['status'] ?? '',
          style: AppTextStyles.statusBadge,
        ),
      ),
    );
  }
  
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'in progress':
        return AppColors.primary;
      case 'on hold':
        return AppColors.warning;
      case 'not started':
        return Colors.grey;
      case 'planned':
        return Colors.purple;
      case 'follow up':
        return Colors.teal;
      case 'cancelled':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Label"),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Leads"),
        BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Invoices"),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
      ],
      currentIndex: 1,
      selectedItemColor: AppColors.primary,
      backgroundColor: AppColors.cardBackground,
      elevation: AppDimensions.elevationXl,
    );
  }
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}