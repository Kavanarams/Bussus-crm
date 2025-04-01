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
  bool _isLoading = true;

  // Filter and sort state
  final Map<String, TextEditingController> _filterControllers = {};
  String? _activeSortColumn;
  bool _sortAscending = true;
  Map<String, String> _columnLabels = {};

  void _updateColumnLabels(List<ColumnInfo> allColumns) {
    _columnLabels.clear();
    for (var column in allColumns) {
      _columnLabels[column.name] = column.label;
    }
  }

  @override
  void initState() {
    super.initState();
    print('📋 List screen initialized for type: ${widget.type}');
    _loadData();
  }

  @override
  void didUpdateWidget(ListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      print('📋 Type changed from ${oldWidget.type} to ${widget.type}');
      _loadData();
    }
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
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);

      print('📋 Loading data for type: ${widget.type}');
      await dataProvider.loadData(widget.type, authProvider.token);
    } catch (e) {
      print('❌ Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Show filter dialog
  // Modify the _showFilterDialog method in _ListScreenState:

  void _showFilterDialog() {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final controllers = Map<String, TextEditingController>.from(_filterControllers);

    // Initialize controllers with current filter values
    dataProvider.activeFilters.forEach((key, value) {
      if (!controllers.containsKey(key)) {
        controllers[key] = TextEditingController();
      }
      controllers[key]!.text = value.toString();
    });

    // Ensure all visible columns have controllers
    for (var column in dataProvider.visibleColumns) {
      if (!controllers.containsKey(column)) {
        controllers[column] = TextEditingController();
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Filter ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // Filter input fields
                ...dataProvider.visibleColumns.map((column) {
                  String label = _columnLabels[column] ?? column;
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
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Clear All'),
              onPressed: () async {
                // Clear controllers
                controllers.forEach((key, controller) {
                  controller.clear();
                });

                // Close the filter dialog
                Navigator.of(dialogContext).pop();

                // Clear filters and show loading state
                setState(() {
                  _isLoading = true;
                });

                // Clear filters
                await dataProvider.clearFilters();

                // Update loading state
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            ),
            TextButton(
              child: Text('Apply'),
              onPressed: () async {
                // Apply filters
                Map<String, String> newFilters = {};
                controllers.forEach((key, controller) {
                  if (controller.text.isNotEmpty) {
                    newFilters[key] = controller.text;
                  }
                });

                // Close the filter dialog
                Navigator.of(dialogContext).pop();

                // Show loading state while filtering
                setState(() {
                  _isLoading = true;
                });

                // Apply filters
                await dataProvider.applyFilters(newFilters, authProvider.token, widget.type);

                // Update loading state
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }
  // Show sort dialog
  void _showSortDialog(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Update column labels
    _updateColumnLabels(dataProvider.allColumns);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Sort ${widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)}'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // Sort options
                ...dataProvider.visibleColumns.map((column) {
                  String label = _columnLabels[column] ?? column;
                  bool isActive = dataProvider.sortColumn == column;
                  return ListTile(
                    title: Text(label),
                    trailing: isActive
                        ? Icon(
                            dataProvider.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            color: Colors.blue,
                          )
                        : null,
                    onTap: () {
                      dataProvider.applySort(column);
                      Navigator.of(dialogContext).pop();
                    },
                  );
                }).toList(),
                // Clear sort option
                if (dataProvider.sortColumn != null)
                  ListTile(
                    title: Text('Clear Sort'),
                    leading: Icon(Icons.clear, color: Colors.red),
                    onTap: () {
                      dataProvider.clearSort();
                      Navigator.of(dialogContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA),
      appBar: AppBar(
        title: Text(
          'List View',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
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
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadData();
            },
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Search functionality
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              // Notifications functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading data...'),
          ],
        ),
      )
          : Consumer<DataProvider>(
        builder: (ctx, dataProvider, _) {
          // Debug prints
          print('📋 Building list view. isLoading: ${dataProvider.isLoading}');
          print('📋 Error: ${dataProvider.error}');
          print('📋 Items count: ${dataProvider.items.length}');

          if (dataProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading data...'),
                ],
              ),
            );
          }

          if (dataProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    dataProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadData();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
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
                      onTap: () =>  _showFilterDialog(),
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
                      onTap: () => _showSortDialog(context),
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
                                  String label = _columnLabels[entry.key] ?? entry.key;
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
                                        dataProvider.applyFilter(entry.key, null);
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
                                      Text('${_columnLabels[dataProvider.sortColumn] ?? dataProvider.sortColumn}'),
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

                              return _buildDynamicItem(item, limitedVisibleColumns, _columnLabels);
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
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onSelected: (String value) async{
                    if (value == 'details') {
                      // Navigate to details page
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(
                            type: widget.type,
                            itemId: item.id,
                          ),
                        ),
                      );
                      // If result is true, refresh the data immediately
                      if (result == true) {
                        final dataProvider = Provider.of<DataProvider>(context, listen: false);
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        await dataProvider.loadData(widget.type, authProvider.token);
                      }
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
                          Icon(Icons.visibility, color: Colors.lightBlue),
                          SizedBox(width: 8),
                          Text('Details', style: TextStyle(color: Colors.lightBlue)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.lightBlue),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.lightBlue)),
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