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
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_decorations.dart';

class ListScreen extends StatefulWidget {
  final String type;

  const ListScreen({super.key, required this.type});

  @override
  _ListScreenState createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final bool _isInitialized = false;
  bool _isLoading = true;
  bool _isScrolledToBottom = false;

  // Filter and sort state
  final Map<String, TextEditingController> _filterControllers = {};
  String? _activeSortColumn;
  final bool _sortAscending = true;
  final Map<String, String> _columnLabels = {};

  // Search state variables
  bool isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Conditional app bar content
        title: isSearchMode
            ? TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: const Color.fromARGB(179, 13, 13, 13)),
            border: InputBorder.none,
          ),
          onChanged: _handleSearchTextChanged,
        )
            : Text(
          'List View',
          style: AppTextStyles.appBarTitle,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
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
              icon: Icon(Icons.refresh),
              onPressed: () {
                _loadData();
              },
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: _toggleSearchMode,
            ),
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {
                // Notifications functionality
              },
            ),
          ],
          if (isSearchMode) ...[
            IconButton(
              icon: Icon(Icons.close),
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
            SizedBox(height: AppDimensions.spacingL),
            Text('Loading data...', style: AppTextStyles.bodyMedium),
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
                  SizedBox(height: AppDimensions.spacingL),
                  Text('Loading data...', style: AppTextStyles.bodyMedium),
                ],
              ),
            );
          }

          if (dataProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  SizedBox(height: AppDimensions.spacingL),
                  Text(
                    dataProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.error),
                  ),
                  SizedBox(height: AppDimensions.spacingL),
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
            return Center(child: Text('No data available', style: AppTextStyles.bodyMedium));
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
                color: AppColors.cardBackground,
                padding: EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingS,
                  horizontal: AppDimensions.spacingXxl
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Filter icon with label below - using filled filter icon
                    GestureDetector(
                      onTap: () =>  _showFilterPage(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: AppDecorations.circleButtonDecoration,
                                child: Padding(
                                  padding: EdgeInsets.all(AppDimensions.spacingS),
                                  child: Icon(
                                    Icons.filter_alt, 
                                    color: AppColors.primaryDark,
                                    size: AppDimensions.iconM
                                  ),
                                ),
                              ),
                              if (dataProvider.activeFilters.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(AppDimensions.spacingXxs),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
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
                          SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            'Filter',
                            style: AppTextStyles.smallActionText,
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
                              Container(
                                decoration: AppDecorations.circleButtonDecoration,
                                child: Padding(
                                  padding: EdgeInsets.all(AppDimensions.spacingS),
                                  child: Icon(
                                    Icons.sort,
                                    color: AppColors.primaryDark,
                                    size: AppDimensions.iconM
                                  ),
                                ),
                              ),
                              if (dataProvider.sortColumn != null)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(AppDimensions.spacingXxs),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
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
                          SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            'Sort',
                            style: AppTextStyles.smallActionText,
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
                            backgroundColor: AppColors.primary,
                            radius: AppDimensions.circleRadius,
                            child: Icon(
                              Icons.add,
                              color: AppColors.textWhite,
                              size: AppDimensions.iconM
                            ),
                          ),
                          SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            'New',
                            style: AppTextStyles.smallActionText,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                    vertical: AppDimensions.spacingXs
                  ),
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
                                  padding: EdgeInsets.only(right: AppDimensions.spacingS),
                                  child: Chip(
                                    backgroundColor: AppColors.primaryLighter.withOpacity(0.3),
                                    label: Text('$label: ${entry.value}'),
                                    deleteIcon: Icon(Icons.close, size: AppDimensions.iconS),
                                    onDeleted: () {
                                      if (_filterControllers.containsKey(entry.key)) {
                                        _filterControllers[entry.key]!.clear();
                                      }
                                      dataProvider.applyFilter(entry.key, null);
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Gap between filter bar and data card
              SizedBox(height: AppDimensions.spacingM),

              // Data card
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingM),
                  child: Card(
                    elevation: AppDimensions.elevationL,
                    color: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppDimensions.radiusM),
                        topRight: Radius.circular(AppDimensions.radiusM),
                        bottomLeft: _isScrolledToBottom ? Radius.circular(AppDimensions.radiusM) : Radius.zero,
                        bottomRight: _isScrolledToBottom ? Radius.circular(AppDimensions.radiusM) : Radius.zero,
                      ),
                    ),
                    margin: _isScrolledToBottom ? EdgeInsets.only(bottom: AppDimensions.spacingM) : EdgeInsets.zero,
                    child: Column(
                      children: [
                        // Title - using plural_label from dataProvider's objectMetadata
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            AppDimensions.spacingL,
                            AppDimensions.spacingS,
                            AppDimensions.spacingL,
                            AppDimensions.spacingS
                          ),
                          child: Text(
                            // Use plural_label if available, otherwise capitalize type
                            dataProvider.objectMetadata?.pluralLabel ??
                                (widget.type.substring(0, 1).toUpperCase() + widget.type.substring(1)),
                            style: AppTextStyles.bodyLarge,
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
                              padding: EdgeInsets.only(bottom: AppDimensions.spacingL),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.shade300, // Darker color for divider
          ),
          Padding(
            padding: EdgeInsets.only(top: AppDimensions.spacingM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: visibleColumns.map((column) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXxs),
                        child: Row(
                          children: [
                            // Left padding for labels
                            SizedBox(width: AppDimensions.spacingS),
                            // Fixed width container for labels
                            SizedBox(
                              width: 110, // Fixed width for all labels
                              child: Text(
                                columnLabels[column] ?? column, // Using the label from columnLabels
                               style: TextStyle(
                                  // Swapped styles - labels now darker and bolder
                                  fontSize: AppDimensions.textM,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,  // Handles long labels
                              ),
                            ),
                            SizedBox(width: AppDimensions.spacingS), // Added space before colon
                            Text(
                              ':',
                              style: TextStyle(
                                fontSize: AppDimensions.textM,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: AppDimensions.spacingS), // Space after colon
                            Expanded(
                              child: Text(
                                item.getStringAttribute(column, defaultValue: '---'),
                                style: TextStyle(
                                  // Swapped styles - values now lighter
                                  fontSize: AppDimensions.textM,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.normal,
                                ),
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
                    size: AppDimensions.iconL,
                    color: Colors.grey.shade600,
                  ),
                  color: AppColors.cardBackground,
                  elevation: AppDimensions.elevationM,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
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
                            backgroundColor: AppColors.success,
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
                          Icon(Icons.visibility, color: AppColors.primary),
                          SizedBox(width: AppDimensions.spacingS),
                          Text('Details', style: AppTextStyles.actionText),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: AppColors.primary),
                          SizedBox(width: AppDimensions.spacingS),
                          Text('Edit', style: AppTextStyles.actionText),
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