import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import 'taskeditscreen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  

  const TaskDetailScreen({
    Key? key,
    required this.taskId,
  }) : super(key: key);

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _taskDetails = {};
  String? _error;
  bool _isEditing = false;
  bool _debugMode = true;
  
  // Controllers for editing fields
  final Map<String, TextEditingController> _controllers = {};
  // Key for the More button to position popup menu
  final GlobalKey _moreButtonKey = GlobalKey();

  void _logDebug(String message) {
  if (_debugMode) {
    print('📌 DEBUG: $message');
  }
}

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadTaskDetails() async {
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

      // Construct the URL for the task details API
      final url = 'https://qa.api.bussus.com/v2/api/task?id=${widget.taskId}';

      print('🌐 Fetching task details from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📤 Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Handle the response based on whether it's a List or Map
        final dynamic responseData = json.decode(response.body);
        
        if (responseData is List && responseData.isNotEmpty) {
          // If the response is directly a List, use the first item
          _taskDetails = Map<String, dynamic>.from(responseData[0]);
          print('📊 Loaded task details directly from list response: $_taskDetails');
        } else if (responseData is Map) {
          // If the response is a Map with a 'preview' key that is a List
          if (responseData.containsKey('preview') && responseData['preview'] is List && responseData['preview'].isNotEmpty) {
            _taskDetails = Map<String, dynamic>.from(responseData['preview'][0]);
            print('📊 Loaded task details from preview in map response: $_taskDetails');
          } else {
            // If the response is a Map with direct task details
            _taskDetails = Map<String, dynamic>.from(responseData);
            print('📊 Loaded task details directly from map response: $_taskDetails');
          }
        } else {
          setState(() {
            _error = 'Unexpected response format or empty response.';
          });
          print('❌ Unexpected response format: $responseData');
        }
        
        // Initialize controllers with current values
        _initControllers();
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Authentication expired. Please log in again.';
        });
      } else {
        setState(() {
          _error = 'Failed to load task details. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error occurred: $e';
      });
      print('❌ Error fetching task details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _initControllers() {
    // Initialize text controllers for each editable field
    _controllers['subject'] = TextEditingController(text: _taskDetails['subject'] ?? '');
    _controllers['due_date'] = TextEditingController(text: _taskDetails['due_date'] ?? '');
    _controllers['assigned_to'] = TextEditingController(text: _taskDetails['assigned_to'] ?? '');
    _controllers['status'] = TextEditingController(text: _taskDetails['status'] ?? '');
    _controllers['related_to'] = TextEditingController(text: _taskDetails['related_to'] ?? '');
    
    if (_taskDetails.containsKey('description')) {
      _controllers['description'] = TextEditingController(text: _taskDetails['description'] ?? '');
    }
  }
  
  void _navigateToEditTask() async {
  _logDebug('Navigating to edit task screen for task ID: ${widget.taskId}');
  
  try {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskEditScreen(
          taskId: widget.taskId,
          taskDetails: _taskDetails,
        ),
      ),
    );
    
    _logDebug('Returned from edit task screen with result: $result');
    
    if (result == true) {
      _logDebug('Reloading task details');
      await _loadTaskDetails();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task details updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    _logDebug('Error navigating to edit screen: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error opening edit screen: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  
  void _showMoreOptionsDialog() {
  _logDebug('Show more options dialog called');
  
  try {
    // Check if context is valid
    if (_moreButtonKey.currentContext == null) {
      _logDebug('More button key context is null');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot show options menu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final RenderBox renderBox = _moreButtonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    
    _logDebug('Showing menu at position: $position');
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + renderBox.size.height,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height + 10,
      ),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text('Mark Complete', style: TextStyle(color: Colors.blue)),
            ],
          ),
          onTap: () {
            // Need to use Future.delayed because menu is closing
            Future.delayed(Duration.zero, () {
              _markTaskComplete();
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text('Change Date', style: TextStyle(color: Colors.blue)),
            ],
          ),
          onTap: () {
            // Need to use Future.delayed because menu is closing
            Future.delayed(Duration.zero, () {
              _changeTaskDate();
            });
          },
        ),
      ],
    );
  } catch (e) {
    _logDebug('Error showing more options menu: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error showing options menu: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  
  void _markTaskComplete() {
  _logDebug('Mark task complete called');
  
  try {
    // Implement your API call here to mark the task as complete
    // For now, show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marking task as complete...'),
        backgroundColor: Colors.blue,
      ),
    );
    
    // In the real implementation, you would update the status and reload the task
  } catch (e) {
    _logDebug('Error marking task complete: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error marking task complete: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  
  void _changeTaskDate() async {
  _logDebug('Change task date called');
  
  try {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    
    _logDebug('Selected date: $pickedDate');
    
    if (pickedDate != null) {
      // Implement your API call here to change the task date
      // For now, show a placeholder message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Date change functionality will be implemented'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  } catch (e) {
    _logDebug('Error changing task date: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error changing task date: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  Future<void> _deleteTask() async {
  _logDebug('Delete task function called for task ID: ${widget.taskId}');
  
  try {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.black)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );

    _logDebug('Delete confirmation dialog result: $confirm');
    
    if (confirm == true) {
      _logDebug('Proceeding with delete');
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token.isEmpty) {
        throw Exception('Authentication token is empty');
      }
      
      final url = 'https://qa.api.bussus.com/v2/api/task';
      
      _logDebug('Sending DELETE request to $url with task ID: ${widget.taskId}');
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "ids": [widget.taskId]
        }),
      );

      _logDebug('Delete response status: ${response.statusCode}');
      _logDebug('Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh the previous screen
      } else {
        String errorMessage;
        try {
          final responseData = json.decode(response.body);
          errorMessage = responseData['message'] ?? 'Failed to delete task';
        } catch (e) {
          errorMessage = 'Failed to delete task. Status code: ${response.statusCode}';
        }

        _logDebug('Error message: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    _logDebug('Error deleting task: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error deleting task: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Task Details',
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Search functionality coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications functionality coming soon')),
              );
            },
          ),
        ],
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
                      _buildHeaderWithActions(),
                      _buildTaskDetailsCard(),
                      // Add related activities section if available
                      if (_taskDetails.containsKey('related_activities'))
                        _buildRelatedActivitiesSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderWithActions() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row with action icons
        Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
          children: [
            // Edit Icon
            _buildActionButton(
              icon: Icons.edit,
              label: 'Edit',
              onTap: _navigateToEditTask,
            ),
            
            // Delete Icon
            _buildActionButton(
              icon: Icons.delete,
              label: 'Delete',
              onTap: _deleteTask,
            ),
            
            // More Icon
            _buildActionButton(
              icon: Icons.more_horiz,
              label: 'More',
              onTap: _showMoreOptionsDialog,
              key: _moreButtonKey,
            ),
          ],
        ),
        
        SizedBox(height: 10),
        
        // Task type
        Text(
          'Task',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        
        // Task subject
        Text(
          _taskDetails['subject'] ?? 'Task',
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

  Widget _buildActionButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  Key? key,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 30.0),
    child: GestureDetector( // Use GestureDetector instead of just Column
      onTap: onTap, // Handle tap here
      child: Column(
        mainAxisSize: MainAxisSize.min,
        key: key,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.all(8),
            child: Icon(
              icon, 
              color: Colors.blue, 
              size: 20,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(fontSize: 10, color: Colors.blue),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTaskDetailsCard() {
    final displayFields = [
      {'label': 'Subject', 'field': 'subject'},
      {'label': 'Due Date', 'field': 'due_date'},
      {'label': 'Status', 'field': 'status'},
      {'label': 'Assigned To', 'field': 'assigned_to'},
      {'label': 'Related To', 'field': 'related_to'},
    ];
    
    // Add description if available
    if (_taskDetails.containsKey('description')) {
      displayFields.add({'label': 'Description', 'field': 'description'});
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            
            // Display all fields
            ...displayFields.map((field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoItem(
                    field['label']!,
                    _formatValue(_taskDetails[field['field']]),
                  ),
                  Divider(height: 20),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
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
   Widget _buildRelatedActivitiesSection() {
    final activities = _taskDetails['related_activities'] as List? ?? [];
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
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
                        '${activities.length}',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          activities.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
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
                      itemCount: activities.length > 2 ? 2 : activities.length,
                      separatorBuilder: (context, index) => Divider(height: 1),
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _buildActivityItem(activity);
                      },
                    ),
                    
                    // Add "View All" button if there are more than 2 activities
                    if (activities.length > 2) ...[
                      Divider(height: 1),
                      InkWell(
                        onTap: () {
                          // Navigate to all activities screen (to be implemented)
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'View All',
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
      ),
    );
  }
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
      onTap: () {
        // Navigate to task detail page for this activity
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(
              taskId: activity['id'],
            ),
          ),
        );
      },
    );
  }
}