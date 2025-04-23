import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import 'package:materio/theme/app_button_styles.dart';

class SortPage extends StatefulWidget {
  final String type;

  SortPage({required this.type});

  @override
  _SortPageState createState() => _SortPageState();
}

class _SortPageState extends State<SortPage> {
  String? _tempSortColumn;
  bool _tempSortAscending = true;
  Map<String, String> _columnLabels = {};

  @override
  void initState() {
    super.initState();
    // Initialize with current sort settings
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    _tempSortColumn = dataProvider.sortColumn;
    _tempSortAscending = dataProvider.sortAscending;
    
    // Update column labels from existing visible columns
    _updateColumnLabels();
  }

  void _updateColumnLabels() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    _columnLabels.clear();
    
    // Use the same approach as in your ListScreen
    for (var column in dataProvider.visibleColumns) {
      var label = dataProvider.allColumns
          .where((col) => col.name == column)
          .map((col) => col.label)
          .firstOrNull ?? column;
      
      _columnLabels[column] = label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA), // Light blue background
      appBar: AppBar(
        title: Text(
          'Sort ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop(false); // Return false if canceled
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Just clear sort settings in provider
              dataProvider.clearSort();
              
              // Navigate back with true to indicate changes were made
              Navigator.of(context).pop(true);
            },
            child: Text('Clear Sort', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: Colors.white, // Pure white card
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select column to sort by',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: const Color.fromARGB(211, 0, 0, 0),
                    ),
                  ),
                ),
                
                Divider(height: 1),
                
                // Column selection list
                Expanded(
                  child: ListView.builder(
                    itemCount: dataProvider.visibleColumns.length,
                    itemBuilder: (context, index) {
                      String column = dataProvider.visibleColumns[index];
                      String label = _columnLabels[column] ?? column;
                      bool isActive = _tempSortColumn == column;
                      
                      return ListTile(
                        title: Text(
                          label,
                          style: TextStyle(
                            color: isActive ? Color.fromARGB(234, 9, 0, 0) : Colors.black87,
                            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        trailing: isActive
                            ? Icon(
                                _tempSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                color: Color.fromARGB(219, 0, 4, 10),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            if (_tempSortColumn == column) {
                              // Toggle sort direction if the same column is selected again
                              _tempSortAscending = !_tempSortAscending;
                            } else {
                              // Set new sort column and default to ascending
                              _tempSortColumn = column;
                              _tempSortAscending = true;
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                
                // Two buttons at bottom: Cancel and Apply Sort
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel Button - White with black text
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: OutlinedButton(
                            onPressed: () {
                              // Navigate back without applying changes
                              Navigator.of(context).pop(false);
                            },
                            style: AppButtonStyles.secondaryButton,
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Apply Sort Button - Blue with white text
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_tempSortColumn != null) {
                                print('🔀 Applying sort in SortPage: $_tempSortColumn (${_tempSortAscending ? 'ascending' : 'descending'})');
                                
                                // Apply the sort settings to the provider
                                dataProvider.applySortWithDirection(_tempSortColumn!, _tempSortAscending);
                                
                                // Important: Mark sorting as active to prevent data reload overwriting it
                                dataProvider.setSortingActive(true);
                              }
                              
                              // Navigate back indicating changes were made
                              Navigator.of(context).pop(true);
                            },
                            style: AppButtonStyles.primaryButton,
                            child: Text(
                              'Apply Sort',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}