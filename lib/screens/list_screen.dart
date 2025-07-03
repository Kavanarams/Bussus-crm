import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/data_provider.dart';
import '../models/dynamic_model.dart';
import 'home_screen.dart';
import 'new_item_screen.dart';
import 'details_screen.dart';
import 'edit_screen.dart';
import 'dart:async';
import 'filterpage.dart' as filter;
import 'sortpage.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_decorations.dart';
import '../theme/app_snackbar.dart';

class ListScreen extends StatefulWidget {
  final String type;

  const ListScreen({super.key, required this.type});

  @override
  _ListScreenState createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _isLoading = true;
  bool _isScrolledToBottom = false;

  // Filter and sort state
  final Map<String, TextEditingController> _filterControllers = {};
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
      } else {
        // When exiting search mode, reload the original data
        _loadData();
      }
    });
  }

  void _handleSearchTextChanged(String query) {
    // If the search text is empty, reload original data
    if (query.isEmpty) {
      if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
      _loadData(); // Load original data immediately when search is cleared
      return;
    }

    // Debounce the search for better performance
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
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

    print('🔍 Performing search for: "$query"');
    await dataProvider.searchData(widget.type, query, authProvider.token);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      // Debug: Check if we have results
      print('🔍 Search completed. Items found: ${dataProvider.items.length}');
      if (dataProvider.items.isEmpty) {
        print('⚠️ No items found for search query: "$query"');
      }
    }
  } catch (e) {
    print('❌ Error searching data: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      // Show error to user
      AppSnackBar.showError(context, 'Search failed. Please try again.');
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
      // Exit search mode when type changes
      if (isSearchMode) {
        setState(() {
          isSearchMode = false;
          _searchController.clear();
        });
      }
      _loadData();
    }
  }

 Future<void> _loadData() async {
  if (!mounted) return;
  
  print('📋 Loading data for type: ${widget.type}');
  
  setState(() {
    _isLoading = true;
  });

  try {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dataProvider = Provider.of<DataProvider>(context, listen: false);
    
    // Load the data - this will reset all filters and sorts
    await dataProvider.loadData(widget.type, authProvider.token);
    
    print('📊 Data loaded successfully. Items: ${dataProvider.items.length}');

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  } catch (e) {
    print('❌ Error loading data: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      AppSnackBar.showError(context, 'Failed to load data. Please try again.');
    }
  }
}

  void _openSortPage() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SortPage(type: widget.type),
    ),
  );
  
  if (result == true) {
    print('🔀 Sort settings changed, refreshing UI');
    if (mounted) {
      setState(() {
        // Just refresh UI - don't reload data
      });
    }
    AppSnackBar.showSuccess(context, 'Sorting applied');
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
      print('🔍 Filters were applied, refreshing UI');
      // The DataProvider should already have the filtered data
      // Just refresh the UI
      if (mounted) {
        setState(() {
          // No need to set _isLoading = true as data is already loaded
        });
      }
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
      print('🔀 Sort was applied, refreshing UI');
      // The DataProvider should already have the sorted data
      // Just refresh the UI
      if (mounted) {
        setState(() {
          // No need to reload data, just refresh UI
        });
      }
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
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
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
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MainLayout(initialIndex: 2),
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
              _toggleSearchMode();
            },
          ),
        ],
      ],
    ),
    body: Column(
      children: [
        // ALWAYS VISIBLE Filter, Sort, New bar - moved outside Consumer
        if (!isSearchMode)
          Container(
            width: double.infinity,
            color: AppColors.cardBackground,
            padding: EdgeInsets.symmetric(
              vertical: AppDimensions.spacingS,
              horizontal: AppDimensions.spacingXxl
            ),
            child: Consumer<DataProvider>(
              builder: (context, dataProvider, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Filter icon with label below
                    GestureDetector(
                      onTap: () => _showFilterPage(context),
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
                );
              },
            ),
          ),
        
        // Rest of the content in Expanded widget
        Expanded(
          child: Consumer<DataProvider>(
            builder: (ctx, dataProvider, _) {
              // Debug prints
              print('📋 Building list view. Provider isLoading: ${dataProvider.isLoading}, Local isLoading: $_isLoading');
              print('📋 Error: ${dataProvider.error}');
              print('📋 Items count: ${dataProvider.items.length}');
              print('📋 Search mode: $isSearchMode');

              return Column(
                children: [
                  // Search results indicator (only during search)
                  if (isSearchMode)
                    Container(
                      color: Colors.blue.shade50,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingL,
                        vertical: AppDimensions.spacingS
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: AppDimensions.iconS, color: Colors.blue.shade600),
                          SizedBox(width: AppDimensions.spacingS),
                          Text(
                            'Search results for "${_searchController.text}" (${dataProvider.items.length} found)',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: AppDimensions.textS,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Gap between action bar and data card
                  SizedBox(height: AppDimensions.spacingM),

                  // Content area - now handles all states
                  Expanded(
                    child: _buildContentArea(dataProvider),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

// Separate method to build content area
Widget _buildContentArea(DataProvider dataProvider) {
  // Show loading if either local loading or provider loading
  if (_isLoading || dataProvider.isLoading) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppDimensions.spacingL),
          Text(
            isSearchMode ? 'Searching...' : 'Loading data...', 
            style: AppTextStyles.bodyMedium
          ),
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
              if (isSearchMode && _searchController.text.isNotEmpty) {
                _performSearch(_searchController.text);
              } else {
                _loadData();
              }
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  final items = dataProvider.items;
  
  // Better empty state handling
  if (items.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchMode ? Icons.search_off : Icons.inbox_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: AppDimensions.spacingL),
          Text(
            isSearchMode 
                ? 'No results found for "${_searchController.text}"'
                : 'No data available',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          if (isSearchMode) ...[
            SizedBox(height: AppDimensions.spacingM),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _toggleSearchMode();
              },
              child: Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }

  // Data display
  final visibleColumns = dataProvider.visibleColumns;
  final limitedVisibleColumns = visibleColumns.length > 3
      ? visibleColumns.sublist(0, 3)
      : visibleColumns;
  final allColumns = dataProvider.allColumns;
  
  // Update column labels mapping
  _updateColumnLabels(allColumns);

  return Padding(
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
          // Title
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              AppDimensions.spacingL,
              AppDimensions.spacingS,
              AppDimensions.spacingL,
              AppDimensions.spacingS
            ),
            child: Text(
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
                                // With this temporarily (for debugging):
                                () {
                                  // Debug logging
                                  item.debugLogField(column);
                                  return item.getDisplayValue(column, defaultValue: '---');
                                }(),
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
                        if (isSearchMode && _searchController.text.isNotEmpty) {
                          // If in search mode, redo the search
                          _performSearch(_searchController.text);
                        } else {
                          // Otherwise load normal data
                          final dataProvider = Provider.of<DataProvider>(context, listen: false);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          await dataProvider.loadData(widget.type, authProvider.token);
                        }
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
                        print('📝 Edit completed successfully, refreshing data...');
                        
                        // Force a refresh of the data to ensure consistency
                        setState(() {
                          _isLoading = true;
                        });
                        
                        try {
                          if (isSearchMode && _searchController.text.isNotEmpty) {
                            // If in search mode, redo the search
                            await _performSearch(_searchController.text);
                          } else {
                            // Otherwise load normal data
                            final dataProvider = Provider.of<DataProvider>(context, listen: false);
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            await dataProvider.loadData(widget.type, authProvider.token);
                          }
                          
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                            AppSnackBar.showSuccess(context, 'Item updated successfully');
                          }
                        } catch (e) {
                          print('❌ Error refreshing data after edit: $e');
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                            AppSnackBar.showError(context, 'Failed to refresh data');
                          }
                        }
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