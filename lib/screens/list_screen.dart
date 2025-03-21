import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'menu_screen.dart';
import 'home_screen.dart';
import 'new_item_screen.dart';
import 'details_screen.dart';
import 'edit_screen.dart';

class ListScreen extends StatefulWidget {
  final String type;

  ListScreen({required this.type});

  @override
  _ListScreenState createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _isInitialized = false;

  // Filter and sort state
  final Map<String, TextEditingController> _filterControllers = {};
  String? _activeSortColumn;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    print('📋 List screen initialized for type: ${widget.type}');
    _loadData();
  }

  @override
  void dispose() {
    // Dispose all filter controllers
    _filterControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_isInitialized) {
      _isInitialized = true;

      // Add a short delay to ensure the widget is fully initialized
      Future.delayed(Duration.zero, () {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final dataProvider = Provider.of<DataProvider>(context, listen: false);

        print('📋 Loading data for type: ${widget.type}');
        dataProvider.loadData(widget.type, authProvider.token);
      });
    }
  }

  // Show filter dialog
  void _showNewFilterDialog(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Initialize controllers with current filter values
    Map<String, TextEditingController> controllers = {};
    for (var column in dataProvider.visibleColumns) {
      controllers[column] = TextEditingController(
        text: dataProvider.activeFilters[column]?.toString() ?? '',
      );
    }

    // Track if a loading dialog is currently showing
    bool isLoadingDialogShowing = false;

    // Function to safely show the loading dialog
    void showLoadingDialog(String message) {
      if (isLoadingDialogShowing) return;

      isLoadingDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text(message)
              ],
            ),
          );
        },
      );
    }

    // Function to safely close the loading dialog
    void hideLoadingDialog() {
      if (isLoadingDialogShowing && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        isLoadingDialogShowing = false;
      }
    }

    // Function to show error dialog
    void showErrorDialog(String message) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              )
            ],
          );
        },
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Filter ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: dataProvider.visibleColumns.map((column) {
                // Get label for the column
                String label = 'Unknown';
                for (var colInfo in dataProvider.allColumns) {
                  if (colInfo.name == column) {
                    label = colInfo.label;
                    break;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: controllers[column],
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: 'Filter by $label',
                      border: OutlineInputBorder(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Clear All'),
              onPressed: () {
                // Clear controllers
                controllers.forEach((key, controller) {
                  controller.clear();
                });

                // Close the filter dialog
                Navigator.of(dialogContext).pop();

                // Using Future.microtask to ensure the dialog is fully closed
                Future.microtask(() async {
                  try {
                    showLoadingDialog("Clearing filters...");

                    // 1. Clear filters
                    await dataProvider.clearFilters();

                    // 2. Load the data again directly
                    await dataProvider.loadData(widget.type, authProvider.token);

                    hideLoadingDialog();

                    // 3. Force UI rebuild
                    setState(() {});
                  } catch (e) {
                    hideLoadingDialog();
                    showErrorDialog('Failed to clear filters: $e');
                  }
                });
              },
            ),
            TextButton(
              child: Text('Apply'),
              onPressed: () {
                // Collect non-empty filter values
                Map<String, String> filters = {};
                for (var entry in controllers.entries) {
                  if (entry.value.text.isNotEmpty) {
                    filters[entry.key] = entry.value.text;
                  }
                }

                // Close dialog
                Navigator.of(dialogContext).pop();

                // Using Future.microtask to ensure the dialog is fully closed
                Future.microtask(() async {
                  try {
                    showLoadingDialog("Applying filters...");

                    // 1. Apply filters
                    if (filters.isNotEmpty) {
                      await dataProvider.applyFilters(filters, authProvider.token, widget.type);
                    } else {
                      await dataProvider.clearFilters();
                    }

                    // 2. Load the data again directly
                    await dataProvider.loadData(widget.type, authProvider.token);

                    hideLoadingDialog();

                    // 3. Trigger UI rebuild
                    setState(() {});
                  } catch (e) {
                    hideLoadingDialog();
                    showErrorDialog('Failed to apply filters: $e');
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }
  // Show sort dialog
  void _showSortDialog(BuildContext context, DataProvider dataProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sort ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: dataProvider.visibleColumns.map((column) {
                // Get label for the column
                String label = 'Unknown';
                for (var colInfo in dataProvider.allColumns) {
                  if (colInfo.name == column) {
                    label = colInfo.label;
                    break;
                  }
                }

                final isActiveSort = dataProvider.sortColumn == column;

                return ListTile(
                  title: Text(label),
                  trailing: isActiveSort
                      ? Icon(
                    dataProvider.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    color: Colors.blue,
                  )
                      : null,
                  onTap: () {
                    dataProvider.applySort(column);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Clear Sort'),
              onPressed: () {
                dataProvider.clearSort();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA), // Light blue background
      appBar: AppBar(
        title: Text(
          'List View',
          style: TextStyle(color: Colors.white, fontSize: 16), // White text color
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // Arrow back icon in white
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MainLayout(initialIndex: 3),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white), // White icon
            onPressed: () {
              // Search functionality
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white), // White icon
            onPressed: () {
              // Notifications functionality
            },
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (ctx, dataProvider, _) {
          // Debug prints
          print('📋 Building list view. isLoading: ${dataProvider.isLoading}');
          print('📋 Error: ${dataProvider.error}');
          print('📋 Items count: ${dataProvider.items.length}');

          if (dataProvider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (dataProvider.error != null) {
            return Center(child: Text(dataProvider.error!));
          }

          final items = dataProvider.items;
          if (items.isEmpty) {
            return Center(child: Text('No data available'));
          }

          final visibleColumns = dataProvider.visibleColumns;
          // Limit visible columns to first 3 if there are more than 3
          final limitedVisibleColumns = visibleColumns.length > 3
              ? visibleColumns.sublist(0, 3)
              : visibleColumns;

          final allColumns = dataProvider.allColumns;

          print('📋 Visible columns: $visibleColumns');
          print('📋 Limited visible columns: $limitedVisibleColumns');
          print('📋 All columns count: ${allColumns.length}');

          // Create a map of column names to labels
          Map<String, String> columnLabels = {};
          for (var column in allColumns) {
            columnLabels[column.name] = column.label;
          }

          return Column(
            children: [
            // Filter, Sort, New bar - reduced vertical height and spacing
            Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 24), // Reduced vertical padding
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, // More compact spacing
              children: [
                // Filter icon with label below - using filled filter icon
                GestureDetector(
                  onTap: () =>  _showNewFilterDialog(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            radius: 16, // Slightly smaller
                            child: Icon(Icons.filter_alt, color: Color(0xFF0D47A1), size: 18), // Changed to filter_alt (filled filter)
                          ),
                          if (dataProvider.activeFilters.isNotEmpty)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 8,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2), // Reduced spacing
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 11, // Slightly smaller
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sort icon with label below
                GestureDetector(
                  onTap: () => _showSortDialog(context, dataProvider),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            radius: 16, // Slightly smaller
                            child: Icon(Icons.sort, color: Color(0xFF0D47A1), size: 18),
                          ),
                          if (dataProvider.sortColumn != null)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 8,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2), // Reduced spacing
                      Text(
                        'Sort',
                        style: TextStyle(
                          fontSize: 11, // Slightly smaller
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // New icon with label below
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewItemScreen(type: widget.type),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        radius: 16, // Slightly smaller
                        child: Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                      SizedBox(height: 2), // Reduced spacing
                      Text(
                        'New',
                        style: TextStyle(
                          fontSize: 11, // Slightly smaller
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Status bar for active filters and sorting
          if (dataProvider.activeFilters.isNotEmpty || dataProvider.sortColumn != null)
          Container(
          color: Colors.grey.shade100,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
          children: [
          Expanded(
          child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          children: [
          if (dataProvider.activeFilters.isNotEmpty)
          ...dataProvider.activeFilters.entries.map((entry) {
          String label = columnLabels[entry.key] ?? entry.key;
          return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Chip(
          backgroundColor: Colors.blue.shade50,
          label: Text('$label: ${entry.value}'),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
          if (_filterControllers.containsKey(entry.key)) {
          _filterControllers[entry.key]!.clear();
          }
          dataProvider.applyFilter(entry.key, null,);
          },
          ),
          );
          }).toList(),
          if (dataProvider.sortColumn != null)
          Chip(
          backgroundColor: Colors.purple.shade50,
          label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          Text('Sort: ${columnLabels[dataProvider.sortColumn] ?? dataProvider.sortColumn}'),
          SizedBox(width: 4),
          Icon(
          dataProvider.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          ),
          ],
          ),
          deleteIcon: Icon(Icons.close, size: 16),
          onDeleted: () {
          dataProvider.clearSort();
          },
          ),
          ],
          ),
          ),
          ),
          if (dataProvider.activeFilters.isNotEmpty || dataProvider.sortColumn != null)
          TextButton(
          onPressed: () {
          dataProvider.clearFilters();
          dataProvider.clearSort();
          _filterControllers.forEach((key, controller) => controller.clear());
          },
          child: Text('Clear All'),
          ),
          ],
          ),
          ),

          // Gap between filter bar and data card
          SizedBox(height: 12), // Reduced from 16 to 12



              // Data card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Card(
                    elevation: 4,
                    color: Colors.white, // Pure white color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Title - with specified font styling
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1),
                            style: TextStyle(
                              fontSize: 16, // As per requirement
                              fontWeight: FontWeight.w400, // As per requirement
                              color: Color(0xDE000000), // #000000DE as per requirement
                            ),
                          ),
                        ),

                        // Data rows
                        Expanded(
                          child: ListView.builder(
                            itemCount: items.length,
                            padding: EdgeInsets.zero, // No bottom padding as requested
                            itemBuilder: (ctx, index) {
                              final item = items[index];

                              return _buildDynamicItem(item, limitedVisibleColumns, columnLabels);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Gap below the card
              SizedBox(height: 12), // Same as the gap above the card
            ],
          );
        },
      ),
      // Bottom navigation bar
      // bottomNavigationBar: BottomNavigationBar(
      //   type: BottomNavigationBarType.fixed,
      //   backgroundColor: Colors.white,
      //   selectedItemColor: Colors.blue,
      //   unselectedItemColor: Colors.grey,
      //   items: [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.favorite),
      //       label: 'Label',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.shopping_cart),
      //       label: 'Products',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.receipt),
      //       label: 'Invoices',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.favorite_border),
      //       label: 'Menu',
      //     ),
      //   ],
      //   onTap: (index) {
      //     // Handle navigation to appropriate screen based on index
      //   },
      // ),
    );
  }

  Widget _buildDynamicItem(dynamic item, List<String> visibleColumns, Map<String, String> columnLabels) {
    // Styles as per requirements
    TextStyle labelStyle = TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF070707)
    );

    TextStyle dataStyle = TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF191919)
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(top: 12, bottom: 0), // Space above item, no space below
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Changed from start to center for vertical alignment
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: visibleColumns.map((column) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            // Left padding for labels
                            SizedBox(width: 8),
                            // Fixed width container for labels
                            Container(
                              width: 110, // Fixed width for all labels
                              child: Text(
                                columnLabels[column] ?? column,
                                style: labelStyle,
                                overflow: TextOverflow.ellipsis,  // Handles long labels
                              ),
                            ),
                            SizedBox(width: 8), // Added space before colon
                            Text(
                              ':',
                              style: labelStyle,
                            ),
                            SizedBox(width: 8), // Space after colon
                            Expanded(
                              child: Text(
                                item.getStringAttribute(column, defaultValue: '---'),
                                style: dataStyle, // Using data-specific style
                                overflow: TextOverflow.ellipsis, // Handles long data
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // More vert icon with popup menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 25,
                    color: Colors.grey.shade600,
                  ),
                  onSelected: (String value) async{
                    if (value == 'details') {
                      // Navigate to details page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(
                            type: widget.type,
                            itemId: item.id,
                          ),
                        ),
                      );
                    } else if (value == 'edit') {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditItemScreen(
                            type: widget.type,
                            itemId: item.id,
                          ),
                        ),
                      );
                        if (result == true) {
                              // We could refresh data here, but it's already done in updateItem method
                              // Just show a confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('item updated successfully!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.only(
                                top: 100,
                                left: 10,
                                right: 10,
                              ),
                            ),
                          );
                        }
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, color: Color(0xFF0D47A1)),
                          SizedBox(width: 8),
                          Text('Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Color(0xFF0D47A1)),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}