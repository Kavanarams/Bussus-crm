import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'details_screen.dart';

class EditItemScreen extends StatefulWidget {
  final String type;
  final String itemId;

  EditItemScreen({required this.type, required this.itemId});

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  DynamicModel? _itemToEdit;
  List<Map<String, dynamic>> sections = [];

  // Map to store form controllers
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadItemDetails();
  }

  @override
  void dispose() {
    // Dispose all controllers when the widget is disposed
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadItemDetails() async {
    if (!_isInitialized) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final dataProvider = Provider.of<DataProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // Find the item in the existing list
        _itemToEdit = dataProvider.items.firstWhere(
              (item) => item.id == widget.itemId,
          orElse: () => throw Exception('Item not found'),
        );

        // Initialize controllers with the current values
        for (var column in dataProvider.allColumns) {
          String value = _itemToEdit!.getStringAttribute(column.name, defaultValue: '');
          _controllers[column.name] = TextEditingController(text: value);
        }

        // Create default sections if none exist
        sections = _createDefaultSections(dataProvider.allColumns);

        _isInitialized = true;
      } catch (e) {
        setState(() {
          _error = 'Failed to load item details: $e';
        });
        print('❌ Error loading item details: $_error');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Create default sections from available columns
  List<Map<String, dynamic>> _createDefaultSections(List<ColumnInfo> columns) {
    // Group columns by their category if available, otherwise use "General"
    Map<String, List<String>> sectionMap = {};

    for (var column in columns) {
      if (column.name == 'id') continue; // Skip ID field

      String sectionName = "General";
      if (sectionMap.containsKey(sectionName)) {
        sectionMap[sectionName]!.add(column.name);
      } else {
        sectionMap[sectionName] = [column.name];
      }
    }

    // Convert the map to the sections format
    return sectionMap.entries.map((entry) {
      return {
        "title": entry.key,
        "fields": entry.value,
      };
    }).toList();
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Create a plain object without the "data" wrapper
      Map<String, dynamic> formData = {};

      // Add all field values directly to the formData object
      _controllers.forEach((key, controller) {
        formData[key] = controller.text;
      });

      // Make sure to include the ID
      formData["id"] = widget.itemId;

      // Remove created_by if it exists
      formData.remove("created_by");

      // Send update request - the updateItem method will add the "data" wrapper
      final result = await dataProvider.updateItem(
          widget.type,
          widget.itemId,
          formData,  // This should be a plain object without "data" wrapper
          authProvider.token
      );

      // Rest of the method remains the same
      if (result['success'])  {
        // Navigate to the details screen instead of just popping
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsScreen(
              type: widget.type,
              itemId: widget.itemId,
            ),
          ),
        );

      } else {
        setState(() {
          _error = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error updating item: $e';
      });
      print('❌ Error updating item: $_error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${_capitalizeFirstLetter(widget.type)}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.blue.shade50,
      body: _isLoading ?
      Center(child: CircularProgressIndicator()) :
      _buildForm(dataProvider),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Label"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Leads"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Invoices"),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
        currentIndex: 1,
        selectedItemColor: Colors.blue,
      ),
    );
  }

  Widget _buildForm(DataProvider dataProvider) {
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: Colors.red)));
    }

    if (_itemToEdit == null) {
      return Center(child: Text('Item not found'));
    }

    // Get all columns
    final columns = dataProvider.allColumns;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Horizontal Line
              Center(
                child: Container(
                  width: 30,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  margin: EdgeInsets.only(bottom: 16),
                ),
              ),

              // Sections with fields
              ...sections.expand((section) => [
                // Section Title & Line Below It
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section["title"],
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
                      SizedBox(height: 4),
                      Divider(color: Colors.grey[400]),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
                ...(section["fields"] as List<String>).map<Widget>((fieldName) {
                  // Find the column info for this field
                  ColumnInfo? foundColumn;
                  for (var col in columns) {
                    if (col.name == fieldName) {
                      foundColumn = col;
                      break;
                    }
                  }

                  // Skip if no column info found
                  if (foundColumn == null) return SizedBox.shrink();

                  return _buildFormField(foundColumn);
                }).toList(),
              ]),

              if (_error != null)
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                    child: Text("Cancel", style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                    child: Text("Save", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(ColumnInfo column) {
    // Make sure controller exists
    if (!_controllers.containsKey(column.name)) {
      _controllers[column.name] = TextEditingController();
    }

    bool isRequired = column.required;
    String fieldLabel = column.label;

    // Check if picklist values are available
    List<String>? picklistValues = _getPicklistValues(column);

    if (picklistValues != null && picklistValues.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: DropdownButtonFormField<String>(
          value: picklistValues.contains(_controllers[column.name]!.text)
              ? _controllers[column.name]!.text
              : null,
          items: picklistValues.map((value) {
            return DropdownMenuItem<String>(
                value: value,
                child: Text(value)
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _controllers[column.name]!.text = newValue ?? '';
            });
          },
          decoration: _inputDecoration(fieldLabel, isRequired),
        ),
      );
    }

    // For other fields, use TextFormField
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _controllers[column.name],
        keyboardType: _getKeyboardType(column),
        decoration: _inputDecoration(fieldLabel, isRequired),
      ),
    );
  }

  // Helper method to get picklist values for a column
  List<String>? _getPicklistValues(ColumnInfo column) {
    // This is a placeholder - implement based on your actual data model
    // Check if there's an attribute or method in ColumnInfo that indicates it's a picklist
    // and returns the possible values
    return null;
  }

  // Helper method to determine keyboard type
  TextInputType _getKeyboardType(ColumnInfo column) {
    // This is a placeholder - implement based on your actual data model
    // For example, you might have a property or method on ColumnInfo
    // that returns the field type
    if (column.name.toLowerCase().contains('phone')) {
      return TextInputType.phone;
    } else if (column.name.toLowerCase().contains('email')) {
      return TextInputType.emailAddress;
    } else if (column.name.toLowerCase().contains('number') ||
        column.name.toLowerCase().contains('amount')) {
      return TextInputType.number;
    }
    return TextInputType.text;
  }

  InputDecoration _inputDecoration(String fieldLabel, bool isRequired) {
    return InputDecoration(
      labelText: "$fieldLabel${isRequired ? ' *' : ''}",
      labelStyle: TextStyle(color: Colors.black),
      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black45),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black45),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blue, width: 2),
      ),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }
}