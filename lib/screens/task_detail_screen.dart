import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

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
  
  // Controllers for editing fields
  final Map<String, TextEditingController> _controllers = {};

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
  
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      
      // If canceling edit, reset the controllers to original values
      if (!_isEditing) {
        _initControllers();
      }
    });
  }
  
 Future<void> _saveChanges() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    if (token.isEmpty) {
      throw Exception('Authentication required. Please log in.');
    }

    // Create a data object with ID references preserved from original task
    final Map<String, dynamic> updatePayload = {
      'data': {
        'id': widget.taskId,
        'subject': _controllers['subject']?.text,
        'status': _controllers['status']?.text,
        'due_date': _controllers['due_date']?.text,
        // Keep the original assigned_to_id instead of the display name
        'assigned_to_id': _taskDetails['assigned_to_id'] ?? _taskDetails['user_id'],
        // Keep the original related_to_id 
        'related_to_id': _taskDetails['related_to_id'],
      }
    };
    
    // Remove any null values from the data object
    updatePayload['data'].removeWhere((key, value) => value == null);

    print('📤 Sending update with payload: ${json.encode(updatePayload)}');

    // Send the PATCH request
    final url = 'https://qa.api.bussus.com/v2/api/task';
    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(updatePayload),
    );

    print('📤 Response status code: ${response.statusCode}');
    print('📤 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      
      setState(() {
        _controllers.forEach((key, controller) {
          _taskDetails[key] = controller.text;
        });
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task updated successfully')),
      );
      
      // Reload task details to confirm changes
      _loadTaskDetails();
    } else {
      // Try alternative format if the first attempt failed
      print('📤 Trying alternative payload format...');
      
      // Create simpler payload without nesting in 'data'
      // Create simpler payload without nesting in 'data'
final Map<String, dynamic> altPayload = {
  'id': widget.taskId,
  'subject': _controllers['subject']?.text,
  'status': _controllers['status']?.text,
  'due_date': _controllers['due_date']?.text,
  'assigned_to_id': _taskDetails['assigned_to_id'] ?? _taskDetails['user_id'],
  'related_to_id': _taskDetails['related_to_id'],
};
      
      altPayload.removeWhere((key, value) => value == null);
      
      print('📤 Sending update with alternative payload: ${json.encode(altPayload)}');
      
      final altResponse = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(altPayload),
      );
      
      print('📤 Alt response status code: ${altResponse.statusCode}');
      print('📤 Alt response body: ${altResponse.body}');
      
      if (altResponse.statusCode == 200) {
        setState(() {
          _controllers.forEach((key, controller) {
            _taskDetails[key] = controller.text;
          });
          _isEditing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task updated successfully')),
        );
        
        // Reload task details to confirm changes
        _loadTaskDetails();
      } else {
        throw Exception('Failed to update task. Status code: ${altResponse.statusCode}');
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
    print('❌ Error updating task: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
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
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('More options functionality coming soon')),
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
                      _buildActionButtons(),
                      _buildTaskName(),
                      _buildTaskDetailsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.edit,
            label: 'Edit',
            onTap: _toggleEditMode,
          ),
          _buildActionButton(
            icon: Icons.delete,
            label: 'Delete',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Delete functionality coming soon')),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.check_circle_outline,
            label: 'Mark Complete',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Mark complete functionality coming soon')),
              );
            },
          ),
          _buildActionButton(
            icon: Icons.calendar_today,
            label: 'Change Date',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Change date functionality coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final Color circleColor = Color(0xFFB3E5FC);
    final Color iconAndTextColor = Color(0xFF2196F3);
    
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: circleColor,
            radius: 18,
            child: Icon(
              icon, 
              color: iconAndTextColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(221, 13, 130, 208),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskName() {
    String subject = _isEditing 
      ? _controllers['subject']?.text ?? 'Task'
      : _taskDetails['subject'] ?? 'Task';
    
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isEditing 
                ? _controllers['status']?.text ?? 'Unknown Status'
                : _taskDetails['status'] ?? 'Unknown Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetailsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            
            // Subject field
            _isEditing
                ? _buildEditableFormField('Subject', 'subject')
                : _buildInlineFormField('Subject', _taskDetails['subject'] ?? ''),
            
            // Due Date field
            _isEditing
                ? _buildEditableFormField('Due Date', 'due_date')
                : _buildInlineFormField('Due Date', _taskDetails['due_date'] ?? ''),
            
            // Assigned To field
            _isEditing
                ? _buildEditableFormField('Assigned To', 'assigned_to')
                : _buildInlineFormField('Assigned To', _taskDetails['assigned_to'] ?? ''),
            
            // Status field
            _isEditing
                ? _buildEditableFormField('Status', 'status')
                : _buildInlineFormField('Status', _taskDetails['status'] ?? ''),
            
            // Related To field
            _isEditing
                ? _buildEditableFormField('Related To', 'related_to')
                : _buildInlineFormField('Related To', _taskDetails['related_to'] ?? ''),
            
            // Description field if available
            if (_taskDetails.containsKey('description') && _controllers.containsKey('description'))
              _isEditing
                  ? _buildEditableFormField('Description', 'description')
                  : _buildInlineFormField('Description', _taskDetails['description'] ?? ''),
                  
            // Add Save/Cancel buttons inside the card when in edit mode
            if (_isEditing) 
              _buildSaveCancelButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineFormField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 4),
      margin: EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.isEmpty ? '–' : value,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: -10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditableFormField(String label, String field) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 4),
      margin: EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!), // Black border instead of blue
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _controllers[field],
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: -10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700], // Black label instead of blue
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSaveCancelButtons() {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _toggleEditMode,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Text('Cancel'),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue[700],
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}