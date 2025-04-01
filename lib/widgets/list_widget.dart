import 'package:flutter/material.dart';
import '../models/dashboard_item.dart';

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
            _buildListContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent() {
    // Check if data is not empty
    if (item.data.isNotEmpty) {
      // Convert data to a list of items
      final listItems = _convertToList(item.data);

      // Use a ListView.builder for better performance
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: listItems.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(listItems[index].toString()),
            dense: true,
            contentPadding: EdgeInsets.zero,
          );
        },
      );
    }
    return const Text('No list items available');
  }

  List<dynamic> _convertToList(Map<String, dynamic> data) {
    // If data contains a 'list' or 'items' key, use that
    if (data.containsKey('list')) {
      return data['list'] is List ? data['list'] : [data['list']];
    }

    if (data.containsKey('items')) {
      return data['items'] is List ? data['items'] : [data['items']];
    }

    // Convert map to a list of key-value pairs if no explicit list is found
    return data.entries.map((entry) => '${entry.key}: ${entry.value}').toList();
  }
}