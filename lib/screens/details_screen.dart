import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
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
  bool _isLoadingActivities = false;
  bool _activitiesSectionExpanded = false;
  
  // Map to keep track of expanded sections - the key is the section title
  Map<String, bool> _expandedSections = {};

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      // Check if token exists
      if (token.isEmpty) {
        setState(() {
          _error = 'Authentication required. Please log in.';
          _isLoading = false;
        });
        return;
      }

      // Construct the URL for the details API
      final url = 'https://qa.api.bussus.com/v2/api/${widget.type}/preview?id=${widget.itemId}';

      print('🌐 Fetching details from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📤 Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Extract the details from the response
        _details = responseData['data'] ?? {};
        _allColumns = _extractColumns(responseData['all_columns'] ?? []);
        _visibleColumns = List<String>.from(responseData['visible_columns'] ?? []);

        // Handle layout sections as a list
        if (responseData['layout'] != null && responseData['layout']['sections'] != null) {
          var sections = responseData['layout']['sections'];
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
        if (responseData['tasks'] != null) {
          _activities = List<Map<String, dynamic>>.from(responseData['tasks']);
          print('📊 Loaded ${_activities.length} activities from preview response');
        }

        print('📊 Loaded details with ${_details.length} fields');
        print('📊 Visible columns: $_visibleColumns');
        print('📊 Layout sections: ${_layoutSections.length}');
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Authentication expired. Please log in again.';
        });
      } else {
        setState(() {
          _error = 'Failed to load details. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error occurred: $e';
      });
      print('❌ Error fetching details: $e');
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
      preferredSize: Size.fromHeight(56),
      child: AppBar(
        title: Text(
            "${widget.type.substring(0, 1).toUpperCase()}${widget.type.substring(1)} Details",
            style: const TextStyle(color: Colors.white, fontSize: 18)
        ),
        backgroundColor: Colors.blue[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {}
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {}
          ),
        ],
      ),
    ),
    backgroundColor: Colors.blue.shade50,
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderInfo(),
                // Use consistent container for all sections
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with action icons - positioned at the top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Edit Icon (Pencil)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue[100],
                    child: IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () async {
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
                  ),
                  SizedBox(height: 2),
                  Text('Edit', style: TextStyle(fontSize: 10, color: Colors.blue[800])),
                ],
              ),

              // Delete Icon
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue[100],
                    child: IconButton(
                      icon: Icon(Icons.delete, color: Colors.blue, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () async {
                        // Delete functionality (unchanged)
                        final confirm = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: Colors.white, // Match card color
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8), // Match card's border radius
    ),
    title: Text('Confirm Delete'),
    content: Text('Are you sure you want to delete this item?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('Cancel', style: TextStyle(color: Colors.black)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Oval shape
            side: BorderSide(color: Colors.grey.shade300), // Optional border
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text('Delete', style: TextStyle(color: Colors.white)),
        style: TextButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Oval shape
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    ],
  ),
);

                        if (confirm == true) {
                          // Delete code (unchanged)
                          try {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final url = 'https://qa.api.bussus.com/v2/api/${widget.type}';
                            print('🗑️ Attempting to delete item from: $url');

                            final response = await http.delete(
                              Uri.parse(url),
                              headers: {
                                'Authorization': 'Bearer ${authProvider.token}',
                                'Content-Type': 'application/json',
                              },
                              body: json.encode({
                                "ids": [widget.itemId]
                              }),
                            );

                            if (response.statusCode == 200) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Item deleted successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.pop(context, true);
                            } else {
                              String errorMessage;
                              try {
                                final responseData = json.decode(response.body);
                                errorMessage = responseData['message'] ?? 'Failed to delete item';
                              } catch (e) {
                                errorMessage = 'Failed to delete item. Status code: ${response.statusCode}';
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            print('❌ Error deleting item: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting item: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 2),
                  Text('Delete', style: TextStyle(fontSize: 10, color: Colors.blue[800])),
                ],
              ),

              // Task Icon (New/Add Activity)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue[100],
                    child: IconButton(
                      icon: Icon(Icons.task_alt, color: Colors.blue, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () async {
                        // Navigate to TaskFormScreen instead of showing dialog
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
                  ),
                  SizedBox(height: 2),
                  Text('Task', style: TextStyle(fontSize: 10, color: Colors.blue[800])),
                ],
              ),

              // More Icon
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue[100],
                    child: IconButton(
                      icon: Icon(Icons.more_horiz, color: Colors.blue, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {
                        // Add more functionality here
                      },
                    ),
                  ),
                  SizedBox(height: 2),
                  Text('More', style: TextStyle(fontSize: 10, color: Colors.blue[800])),
                ],
              ),
            ],
          ),

          // Add some spacing between icons and text
          SizedBox(height: 16),

          // Object type (Lead, Account, etc.)
          Text(
            objectType,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),

          // Name with title
          Text(
            displayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // New method for expandable sections
  Widget _buildExpandableSection(Map<String, dynamic> section) {
  final title = section['title'] ?? 'Details';
  final fields = List<String>.from(section['fields'] ?? []);
  final isExpanded = _expandedSections[title] ?? false;

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8), // Consistent vertical margin
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    color: Colors.white,
    elevation: 2, // Add consistent elevation
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
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.blue[700],
                ),
              ],
            ),
          ),
        ),
        
        // Expandable content
        if (isExpanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
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
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}


  // Updated default section to be expandable
  Widget _buildExpandableDefaultSection() {
  final isExpanded = _expandedSections['Details'] ?? false;
  
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8), // Consistent vertical margin
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    color: Colors.white,
    elevation: 2, // Add consistent elevation
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
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.blue[700],
                ),
              ],
            ),
          ),
        ),
        
        // Expandable content
        if (isExpanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
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
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

  // Updated to make labels lighter and values darker
  Widget _infoItem(String title, String value, bool required) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              "$title${required ? ' *' : ''}",
              style: TextStyle(
                  fontWeight: FontWeight.normal, // Changed from bold to normal
                  fontSize: 13,
                  color: Colors.grey[600] // Changed from dark to lighter grey
              )
          ),
          Text(
              value,
              style: const TextStyle(
                  fontSize: 14, // Slightly larger
                  fontWeight: FontWeight.w500, // Added medium weight
                  color: Colors.black // Darker color for better visibility
              )
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
    margin: const EdgeInsets.symmetric(vertical: 8),
    elevation: 2,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
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
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Open Activities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$activitiesCount',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(
                  _activitiesSectionExpanded 
                      ? Icons.keyboard_arrow_up 
                      : Icons.keyboard_arrow_down,
                  color: Colors.blue[700],
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
                    padding: const EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _activities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No activities found',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
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
                          InkWell(
                            onTap: () {
                              // Navigate to the all activities screen
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (context) => AllActivitiesScreen(
                                    activities: _activities, 
                                    objectType: widget.type,
                                    objectName: _details['name'] ?? 'Unknown',
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'View All ${_activities.length} Activities',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
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

// Create a helper method to build activity items to avoid code duplication
Widget _buildActivityItem(Map<String, dynamic> activity) {
  return ListTile(
    dense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    title: Text(
      activity['subject'] ?? 'No Subject',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Due Date: ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${activity['due_date'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
        SizedBox(height: 2),
        Row(
          children: [
            Text(
              'Status: ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${activity['status'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    ),
    trailing: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(activity['status']),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activity['status'] ?? '',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
  
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'on hold':
        return Colors.orange;
      case 'not started':
        return Colors.grey;
      case 'planned':
        return Colors.purple;
      case 'follow up':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
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
    selectedItemColor: Colors.blue,
    backgroundColor: Colors.white, // Changed to white to match card color
    elevation: 8, // Added elevation for a subtle shadow
  );
}
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}