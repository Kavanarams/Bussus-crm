import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Sort ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}',
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
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
            // Make sure the text is visible on app bar background
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Clear Sort',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacingL),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(AppDimensions.spacingL),
                  child: Text(
                    'Select column to sort by',
                    style: AppTextStyles.subheading,
                  ),
                ),
                
                Divider(height: 1, color: AppColors.divider),
                
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
                          style: isActive 
                              ? AppTextStyles.fieldValue
                              : AppTextStyles.bodyMedium,
                        ),
                        trailing: isActive
                            ? Icon(
                                _tempSortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                color: AppColors.primary,
                                size: AppDimensions.iconM,
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
                  padding: EdgeInsets.all(AppDimensions.spacingL),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel Button
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: AppDimensions.spacingS),
                          child: OutlinedButton(
                            onPressed: () {
                              // Navigate back without applying changes
                              Navigator.of(context).pop(false);
                            },
                            child: Text('Cancel'),
                          ),
                        ),
                      ),
                      
                      // Apply Sort Button
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: AppDimensions.spacingS),
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
                            child: Text('Apply Sort'),
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