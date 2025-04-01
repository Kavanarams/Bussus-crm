import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'edit_screen.dart';

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
      final url = 'http://88.222.241.78/v2/api/${widget.type}/preview?id=${widget.itemId}';

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

  Future<bool> _showAddActivityDialog() {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController dueDateController = TextEditingController();
    final TextEditingController assignedToController = TextEditingController();
    String selectedStatus = 'Not Started';
    DateTime? selectedDate;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Add Activity'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Enter activity subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2025, 12, 31),
                    );
                    if (picked != null && picked != selectedDate) {
                      selectedDate = picked;
                      dueDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: dueDateController,
                      decoration: InputDecoration(
                        labelText: 'Due Date',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: assignedToController,
                  decoration: InputDecoration(
                    labelText: 'Assigned To',
                    hintText: 'Enter assignee name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Not Started',
                    'In Progress',
                    'Completed',
                    'On Hold',
                    'Cancelled',
                    'Planned',
                    'Follow Up'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedStatus = newValue;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () async {
                if (subjectController.text.isEmpty || 
                    dueDateController.text.isEmpty || 
                    assignedToController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final token = authProvider.token;

                final taskData = {
                  'subject': subjectController.text,
                  'status': selectedStatus,
                  'due_date': dueDateController.text,
                  'assigned_to': assignedToController.text,
                  'related_object_id': widget.itemId,
                  'related_to': _details['name'] ?? '',
                  'user_id': 20, // Using the user_id from the example
                };

                try {
                  final response = await http.post(
                    Uri.parse('http://88.222.241.78/v2/api/account/task'),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                    body: json.encode({
                      'data': taskData
                    }),
                  );

                  print('📤 Create task response: ${response.body}');

                  if (response.statusCode == 201) {
                    Navigator.of(dialogContext).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Activity added successfully')),
                    );
                    // Reload the details to get the updated activities
                    _loadDetails();
                  } else {
                    final responseData = json.decode(response.body);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(responseData['message'] ?? 'Failed to add activity')),
                    );
                  }
                } catch (e) {
                  print('❌ Error creating task: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating activity: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
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
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {}
            ),
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
                  ..._layoutSections.isNotEmpty
                      ? _layoutSections.map((section) {
                          return _buildSection(section);
                        }).toList()
                      : [_buildDefaultSection()],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await _showAddActivityDialog();
                        if (success) {
                          _loadDetails(); // Reload activities after adding a new one
                        }
                      },
                      icon: Icon(Icons.add),
                      label: Text('Add Activity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Activities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildActivitiesSection(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: ElevatedButton.icon(
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
              icon: Icon(Icons.edit, color: Colors.white, size: 16),
              label: Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Confirm Delete'),
                    content: Text('Are you sure you want to delete this item?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final url = 'http://88.222.241.78/v2/api/${widget.type}';
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

                    print('📤 Delete response status code: ${response.statusCode}');
                    print('📤 Delete response body: ${response.body}');

                    if (response.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Item deleted successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context, true); // Return true to indicate successful deletion
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
              icon: Icon(Icons.delete, color: Colors.white, size: 16),
              label: Text('Delete', style: TextStyle(color: Colors.white, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(Map<String, dynamic> section) {
    final title = section['title'] ?? 'Details';
    final fields = List<String>.from(section['fields'] ?? []);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
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
    );
  }

  Widget _buildDefaultSection() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
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
    );
  }

  Widget _infoItem(String title, String value, bool required) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              "$title${required ? ' *' : ''}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF292929)
              )
          ),
          Text(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3B3B3B)
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
    if (_isLoadingActivities) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No activities found',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: _activities.map((activity) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
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
                  SizedBox(height: 8),
                  Text(
                    'Due Date: ${activity['due_date'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Status: ${activity['status'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 14),
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
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
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
    );
  }
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}