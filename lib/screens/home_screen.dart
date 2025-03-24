import 'package:flutter/material.dart';
import 'package:materio/models/dashboard_model.dart';
import 'package:materio/services//dashboard_service.dart';
import 'list_screen.dart';
import 'menu_screen.dart';

// Main layout that contains the persistent bottom navigation
class MainLayout extends StatefulWidget {
  final int initialIndex;
  final String? screenType;

  MainLayout({this.initialIndex = 0, this.screenType});

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _screens = [
      HomeContent(),
      ListScreen(type: widget.screenType ?? 'product'),
      ListScreen(type: 'invoice'),
      MenuScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Label',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Invoices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Menu',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final DashboardService _dashboardService = DashboardService();
  List<GridItem> gridItems = [];
  bool isLoading = true;
  String? errorMessage;

  // Track the item being resized
  GridItem? resizingItem;
  Offset? resizeStartPosition;
  double? initialWidth;
  double? initialHeight;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final dashboardItems = await _dashboardService.fetchDashboard();

      // Convert API data to GridItems
      final List<GridItem> items = dashboardItems.map((item) {
        return GridItem(
          id: item.id,
          row: item.row,
          column: item.column,
          width: item.width,
          height: item.height,
          color: Colors.white,
          number: int.tryParse(item.id) ?? 0,
          title: item.title,
          type: item.type,
          data: item.data,
        );
      }).toList();

      setState(() {
        gridItems = items;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load dashboard: $e';
        isLoading = false;

        // Fallback to default grid items if API fails
        gridItems = [
          GridItem(id: '1', row: 0, column: 0, width: 0.5, height: 0.2, color: Colors.white, number: 1, title: 'Item 1'),
          GridItem(id: '2', row: 0, column: 1, width: 0.5, height: 0.2, color: Colors.white, number: 2, title: 'Item 2'),
          GridItem(id: '3', row: 1, column: 0, width: 0.5, height: 0.3, color: Colors.white, number: 3, title: 'Item 3'),
          GridItem(id: '4', row: 1, column: 1, width: 0.5, height: 0.3, color: Colors.white, number: 4, title: 'Item 4'),
          GridItem(id: '5', row: 2, column: 0, width: 0.5, height: 0.5, color: Colors.white, number: 5, title: 'Item 5'),
          GridItem(id: '6', row: 2, column: 1, width: 0.5, height: 0.5, color: Colors.white, number: 6, title: 'Item 6'),
        ];
      });
    }
  }
  // Handle grid item placement after drag
  void onItemDrop(GridItem draggedItem, Offset dropPosition, Size containerSize) {
    setState(() {
      // Calculate the new row and column based on drop position
      final rowCount = 3; // Number of rows in your grid
      final columnCount = 2; // Number of columns in your grid

      final rowHeight = containerSize.height / rowCount;
      final columnWidth = containerSize.width / columnCount;

      final newRow = (dropPosition.dy / rowHeight).floor();
      final newColumn = (dropPosition.dx / columnWidth).floor();

      // Make sure we stay within boundaries
      final validRow = newRow.clamp(0, rowCount - 1);
      final validColumn = newColumn.clamp(0, columnCount - 1);

      // Check if there's an item at the target position
      final targetItem = gridItems.firstWhere(
            (item) => item.row == validRow && item.column == validColumn && item.id != draggedItem.id,
        orElse: () => draggedItem,
      );

      if (targetItem.id != draggedItem.id) {
        // Swap positions with the target item
        final tempRow = draggedItem.row;
        final tempColumn = draggedItem.column;

        draggedItem.row = targetItem.row;
        draggedItem.column = targetItem.column;

        targetItem.row = tempRow;
        targetItem.column = tempColumn;
      } else {
        // Move to the empty position
        draggedItem.row = validRow;
        draggedItem.column = validColumn;
      }

      // Reset drag flag
      draggedItem.isBeingDragged = false;
    });
  }

  // Handle resizing of grid items
  void startResize(GridItem item, Offset position) {
    setState(() {
      resizingItem = item;
      resizeStartPosition = position;
      initialWidth = item.width;
      initialHeight = item.height;
    });
  }

  void updateResize(Offset position, Size containerSize) {
    if (resizingItem == null || resizeStartPosition == null ||
        initialWidth == null || initialHeight == null) return;

    setState(() {
      // Calculate delta movement
      final dx = position.dx - resizeStartPosition!.dx;
      final dy = position.dy - resizeStartPosition!.dy;

      // Convert to percentage of container size
      final widthDelta = dx / containerSize.width;
      final heightDelta = dy / containerSize.height;

      // Update dimensions with constraints
      resizingItem!.width = (initialWidth! + widthDelta).clamp(0.2, 1.0);
      resizingItem!.height = (initialHeight! + heightDelta).clamp(0.1, 0.8);

      // Adjust other items to accommodate the resized item
      _adjustGridLayout();
    });
  }

  void endResize() {
    setState(() {
      resizingItem = null;
      resizeStartPosition = null;
      initialWidth = null;
      initialHeight = null;
    });
  }

  // Adjust grid layout to handle item resizing
  void _adjustGridLayout() {
    // This is a simplified version. A more sophisticated algorithm
    // would check for collisions and adjust neighboring items

    if (resizingItem == null) return;

    // Make sure all items fit properly in the grid
    for (var item in gridItems) {
      if (item.id == resizingItem!.id) continue;

      // Check if item is in the same row as the resizing item
      if (item.row == resizingItem!.row) {
        // If resizing item is in column 0 and gets wider, shrink item in column 1
        if (resizingItem!.column == 0 && item.column == 1) {
          item.width = (1.0 - resizingItem!.width).clamp(0.2, 0.8);
        }
        // If resizing item is in column 1 and gets wider, shrink item in column 0
        else if (resizingItem!.column == 1 && item.column == 0) {
          item.width = (1.0 - resizingItem!.width).clamp(0.2, 0.8);
        }
      }

      // Adjust heights of items in other rows if needed
      // This is a simplified approach - a real implementation would be more complex
      if (resizingItem!.row == 0 && (item.row == 1 || item.row == 2)) {
        // If top row expands, adjust middle and bottom rows
        if (item.row == 1) {
          // Middle row gets compressed if top row expands
          item.height = ((1.0 - resizingItem!.height) * 0.4).clamp(0.1, 0.4);
        } else {
          // Bottom row uses remaining space
          final middleRowItem = gridItems.firstWhere((i) => i.row == 1 && i.column == item.column,
              orElse: () => gridItems.firstWhere((i) => i.row == 1));
          item.height = ((1.0 - resizingItem!.height - middleRowItem.height))
              .clamp(0.2, 0.5);
        }
      } else if (resizingItem!.row == 1 && (item.row == 0 || item.row == 2)) {
        // If middle row expands, adjust top and bottom rows
        if (item.row == 0) {
          // Top row gets compressed if middle row expands
          item.height = ((1.0 - resizingItem!.height) * 0.3).clamp(0.1, 0.3);
        } else {
          // Bottom row uses remaining space
          final topRowItem = gridItems.firstWhere((i) => i.row == 0 && i.column == item.column,
              orElse: () => gridItems.firstWhere((i) => i.row == 0));
          item.height = ((1.0 - resizingItem!.height - topRowItem.height))
              .clamp(0.2, 0.5);
        }
      } else if (resizingItem!.row == 2 && (item.row == 0 || item.row == 1)) {
        // If bottom row expands, adjust top and middle rows
        if (item.row == 0) {
          // Top row gets compressed if bottom row expands
          item.height = ((1.0 - resizingItem!.height) * 0.3).clamp(0.1, 0.3);
        } else {
          // Middle row uses remaining space
          final topRowItem = gridItems.firstWhere((i) => i.row == 0 && i.column == item.column,
              orElse: () => gridItems.firstWhere((i) => i.row == 0));
          item.height = ((1.0 - resizingItem!.height - topRowItem.height))
              .clamp(0.1, 0.4);
        }
      }
    }
  }

  // The rest of your methods (onItemDrop, startResize, updateResize, etc.) remain the same

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1976D2),
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.menu),
          color: Colors.white,
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFC7E8F1),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 24.0),
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? _buildErrorWidget()
                : _buildDashboardGrid(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Drag to move items. Use the resize handle to adjust size.'),
              duration: Duration(seconds: 3),
            ),
          );
        },
        child: Icon(Icons.help_outline),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          SizedBox(height: 16),
          Text(
            errorMessage ?? 'An error occurred',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDashboardData,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            if (resizingItem != null) {
              updateResize(details.localPosition, Size(constraints.maxWidth, constraints.maxHeight));
            }
          },
          onPanEnd: (details) {
            if (resizingItem != null) {
              endResize();
            }
          },
          child: Stack(
            children: gridItems.map((item) {
              // Calculate absolute position and size for each grid item
              final rowHeight = constraints.maxHeight / 3; // Assuming 3 rows
              final columnWidth = constraints.maxWidth / 2; // Assuming 2 columns

              final left = item.column * columnWidth;
              final top = item.row * rowHeight;
              final width = item.width * constraints.maxWidth;
              final height = item.height * constraints.maxHeight;

              return Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
                child: Opacity(
                  opacity: item.isBeingDragged ? 0.7 : 1.0,
                  child: Draggable<GridItem>(
                    data: item,
                    feedback: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        width: width,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: _buildDashboardItemContent(item),
                      ),
                    ),
                    onDragStarted: () {
                      setState(() {
                        item.isBeingDragged = true;
                      });
                    },
                    onDragEnd: (details) {
                      if (details.wasAccepted) return;

                      // If not accepted by a DragTarget, handle manually
                      if (details.offset.dx >= 0 &&
                          details.offset.dx <= constraints.maxWidth &&
                          details.offset.dy >= 0 &&
                          details.offset.dy <= constraints.maxHeight) {
                        onItemDrop(item, details.offset, Size(constraints.maxWidth, constraints.maxHeight));
                      } else {
                        setState(() {
                          item.isBeingDragged = false;
                        });
                      }
                    },
                    childWhenDragging: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: Colors.grey,
                          width: 2,
                        ),
                      ),
                    ),
                    child: DragTarget<GridItem>(
                      onAccept: (draggedItem) {
                        onItemDrop(
                            draggedItem,
                            Offset(left + width / 2, top + height / 2),
                            Size(constraints.maxWidth, constraints.maxHeight)
                        );
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.0),
                            border: candidateData.isNotEmpty
                                ? Border.all(color: Colors.blue, width: 3)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              _buildDashboardItemContent(item),
                              // Resize handle in bottom-right corner
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: GestureDetector(
                                  onPanStart: (details) {
                                    startResize(item, details.localPosition);
                                  },
                                  child: Container(
                                    height: 24,
                                    width: 24,
                                    color: Colors.transparent,
                                    child: Icon(
                                      Icons.open_with,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDashboardItemContent(GridItem item) {
    // Render different widget based on item type
    switch (item.type) {
      case 'chart':
        return _buildChartWidget(item);
      case 'stats':
        return _buildStatsWidget(item);
      case 'list':
        return _buildListWidget(item);
      default:
        return _buildDefaultWidget(item);
    }
  }

  Widget _buildChartWidget(GridItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            item.title ?? 'Chart',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Icon(
              Icons.bar_chart,
              size: 48,
              color: Colors.blue[400],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsWidget(GridItem item) {
    final Map<String, dynamic> data = item.data ?? {};
    final String value = data['value']?.toString() ?? '0';
    final String unit = data['unit']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            item.title ?? 'Statistics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListWidget(GridItem item) {
    final List<dynamic> listItems = item.data?['items'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            item.title ?? 'List',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: listItems.isEmpty
              ? Center(child: Text('No items'))
              : ListView.builder(
            itemCount: listItems.length > 5 ? 5 : listItems.length,
            itemBuilder: (context, index) {
              final item = listItems[index];
              return ListTile(
                dense: true,
                title: Text(
                  item['title'] ?? 'Item ${index + 1}',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: item['subtitle'] != null
                    ? Text(
                  item['subtitle'],
                  style: TextStyle(fontSize: 12),
                )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultWidget(GridItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.title ?? 'Item ${item.number}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '#${item.number}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[400],
          ),
        ),
      ],
    );
  }
}

// Update the GridItem class to support additional fields from API
class GridItem {
  final String id;
  int row;
  int column;
  double width;
  double height;
  final Color color;
  final int number;
  final String? title;
  final String? type;
  final Map<String, dynamic>? data;
  bool isBeingDragged = false;

  GridItem({
    required this.id,
    required this.row,
    required this.column,
    this.width = 1.0,
    this.height = 1.0,
    required this.color,
    required this.number,
    this.title,
    this.type,
    this.data,
  });
}
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MainLayout();
  }
}