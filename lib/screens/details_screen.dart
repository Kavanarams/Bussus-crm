import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../models/dynamic_model.dart';

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
      appBar: AppBar(
        title: Text(
            "${widget.type.toUpperCase()} Details",
            style: const TextStyle(color: Colors.white, fontSize: 18)
        ),
        backgroundColor: Colors.blue[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () {}),
        ],
      ),
      backgroundColor: Colors.blue.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderInfo(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _layoutSections.isNotEmpty
                      ? _layoutSections.map((section) {
                    return _buildSection(section);
                  }).toList()
                      : [_buildDefaultSection()],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Icon(Icons.folder, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "Open All ${widget.type.capitalize()}",
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ],
          ),
          const Icon(Icons.more_vert),
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