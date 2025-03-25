import 'package:flutter/material.dart';
import '../models/dashboard_item.dart';

class WidgetFactory {
  static Widget buildWidget(DashboardItem item) {
    final type = item.type.toLowerCase();

    // Handle both your original types and the new API types
    if (type == 'chart' || type.contains('chart')) {
      return ChartWidget(item: item);
    } else if (type == 'stats') {
      return StatsWidget(item: item);
    } else if (type == 'list') {
      return ListWidget(item: item);
    } else if (type == 'card') {
      return CardWidget(item: item);
    } else {
      // Print the type for debugging
      print('Unknown widget type: $type');
      return DefaultWidget(item: item);
    }
  }
}

class ChartWidget extends StatelessWidget {
  final DashboardItem item;

  const ChartWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine specific chart type
    String chartType = "Generic Chart";
    if (item.type.toLowerCase().contains("pie")) {
      chartType = "Pie Chart";
    } else if (item.type.toLowerCase().contains("line")) {
      chartType = "Line Chart";
    } else if (item.type.toLowerCase().contains("bar")) {
      chartType = "Bar Chart";
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "ID: ${item.id}",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text("$chartType Visualization"),
              // Replace with actual chart implementation based on item.data
            ),
            if (item.data.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Data: ${item.data}"),
              ),
          ],
        ),
      ),
    );
  }
}

// Keep the other widget classes (StatsWidget, ListWidget, CardWidget, DefaultWidget) unchanged
class StatsWidget extends StatelessWidget {
  final DashboardItem item;

  const StatsWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text("Stats Widget Placeholder"),
          ],
        ),
      ),
    );
  }
}

class ListWidget extends StatelessWidget {
  final DashboardItem item;

  const ListWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text("List Widget Placeholder"),
          ],
        ),
      ),
    );
  }
}

class CardWidget extends StatelessWidget {
  final DashboardItem item;

  const CardWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text("Card Widget Content"),
          ],
        ),
      ),
    );
  }
}

class DefaultWidget extends StatelessWidget {
  final DashboardItem item;

  const DefaultWidget({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "ID: ${item.id}",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text("Unknown widget type: ${item.type}"),
            if (item.data.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Data: ${item.data}"),
              ),
          ],
        ),
      ),
    );
  }
}