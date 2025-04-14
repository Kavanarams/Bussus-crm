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
import 'dart:async';
import 'filter_logic.dart' as filterlogic;
import 'filterpage.dart' as filter;
import 'sortpage.dart';

class ListScreen extends StatefulWidget {
  final String type;

  ListScreen({required this.type});

  @override
  _ListScreenState createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isScrolledToBottom = false;

  // Filter and sort state
  final Map<String, TextEditingController> _filterControllers = {};
  String? _activeSortColumn;
  bool _sortAscending = true;
  Map<String, String> _columnLabels = {};

  // Search state variables
  bool isSearchMode = false;
  TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _filterControllers.forEach((key, controller) => controller.dispose());
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    super.dispose();
  }

  void _toggleSearchMode() {
    setState(() {
      isSearchMode = !isSearchMode;
      if (isSearchMode) {
        _searchController.clear();
        // Request focus after the state has been updated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  void _handleSearchTextChanged(String query) {
    // If the search text is empty and backspace was pressed, exit search mode
    if (query.isEmpty && _searchController.text.isEmpty) {
      _toggleSearchMode();
      // Also reload the original data
      _loadData();
      return;
    }

    // Debounce the search for better performance
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  // Modify your _performSearch method
  void _performSearch(String query) async {
    if (query.isEmpty) {
      // If query is empty, reload all data
      _loadData();
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);

      await dataProvider.searchData(widget.type, query, authProvider.token);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error searching data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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

  // Modify your _loadData method to ensure it doesn't trigger setState during build:
  Future<void> _loadData() async {
    // Don't set state if we're in the middle of building
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dataProvider = Provider.of<DataProvider>(context, listen: false);

      // Schedule this after the current build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await dataProvider.loadData(widget.type, authProvider.token);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openSortPage() async {
    // Navigate to sort page and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SortPage(type: widget.type),
      ),
    );
    
    // Handle the result
    if (result == true) {
      // Sort settings were changed
      print('🔀 Returning from SortPage with changes');
      
      // No need to reload data - the provider's sorting is already applied
      // Just refresh the UI by calling setState
      setState(() {});
      
      // Show a confirmation snackbar if you want
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorting applied'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showFilterPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => filter.FilterPage(
          type: widget.type,
        ),
      ),
    ).then((filtersApplied) {
      if (filtersApplied == true) {
        // Force refresh if filters were applied or cleared
        setState(() {
          _isLoading = true;
        });
        
        // Make sure the data is reloaded
        _loadData();
      }
    });
  }
 
  void _showSortDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SortPage(
          type: widget.type,
        ),
      ),
    ).then((sortApplied) {
      if (sortApplied == true) {
        // Force refresh if sort was applied or cleared
        setState(() {
          _isLoading = true;
        });
        
        // Reload data explicitly
        _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE0F7FA),
      appBar: AppBar(
        // Conditional app bar content
        title: isSearchMode
            ? TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: _handleSearchTextChanged,
        )
            : Text(
          'List View',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (isSearchMode) {
              _toggleSearchMode();
              _loadData(); // Reload original data
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MainLayout(initialIndex: 3),
                ),
              );
            }
          },
        ),
        actions: [
          if (!isSearchMode) ...[
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _loadData();
              },
            ),
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: _toggleSearchMode,
            ),
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () {
                // Notifications functionality
              },
            ),
          ],
          if (isSearchMode) ...[
            IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                _handleSearchTextChanged('');
              },
            ),
          ],
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
          
          // Update column labels mapping
          _updateColumnLabels(allColumns);

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
                      onTap: () =>  _showFilterPage(context),
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
              if (dataProvider.activeFilters.isNotEmpty)
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
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                        bottomLeft: _isScrolledToBottom ? Radius.circular(12) : Radius.zero,
                        bottomRight: _isScrolledToBottom ? Radius.circular(12) : Radius.zero,
                      ),
                    ),
                    margin: _isScrolledToBottom ? EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
                    child: Column(
                      children: [
                        // Title - CHANGED: Now using plural_label from dataProvider's objectMetadata
                        Container(
  width: double.infinity,
  padding: EdgeInsets.fromLTRB(16, 8, 16, 8), // Reduced top padding from 16 to 8
  child: Text(
    // Use plural_label if available, otherwise capitalize type
    dataProvider.objectMetadata?.pluralLabel ??
        (widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)),
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xDE000000),
    ),
  ),
),

                        // Data rows
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (scrollInfo is ScrollEndNotification) {
                                // When scroll ends, check if we're at the bottom
                                if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                                  if (!_isScrolledToBottom) {
                                    setState(() {
                                      _isScrolledToBottom = true;
                                    });
                                  }
                                } else if (_isScrolledToBottom) {
                                  setState(() {
                                    _isScrolledToBottom = false;
                                  });
                                }
                              }
                              return true;
                            },
                            child: ListView.builder(
                              itemCount: items.length,
                              padding: EdgeInsets.only(bottom: 16),
                              itemBuilder: (ctx, index) {
                                final item = items[index];
                                return _buildDynamicItem(item, limitedVisibleColumns, _columnLabels);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                                columnLabels[column] ?? column, // Using the label from columnLabels
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
                            content: Text('Item updated successfully!'),
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