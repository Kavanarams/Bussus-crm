import 'package:flutter/material.dart';
import '../models/dashboard_item.dart';

class DefaultWidget extends StatelessWidget {
  final DashboardItem item;

  const DefaultWidget({super.key, required this.item});

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
            Text("Unsupported widget type: ${item.type}"),
            if (item.data.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Raw Data: ${item.data}"),
              ),
          ],
        ),
      ),
    );
  }
}