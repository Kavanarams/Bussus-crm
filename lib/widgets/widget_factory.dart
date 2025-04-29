import 'package:flutter/material.dart';
import '../models/dashboard_item.dart';
import 'package:fl_chart/fl_chart.dart';
import 'card_widget.dart';
import 'stats_widget.dart';
import 'list_widget.dart';
import 'default_widget.dart';


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

  const ChartWidget({super.key, required this.item});

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
            _buildChartBasedOnType(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBasedOnType() {
    final type = item.type.toLowerCase();
    final data = item.data;

    // Validate data
    if (data.isEmpty) {
      return const Center(child: Text('No chart data available'));
    }

    try {
      if (type.contains('pie')) {
        return _buildPieChart(data);
      } else if (type.contains('line')) {
        return _buildLineChart(data);
      } else if (type.contains('bar')) {
        return _buildBarChart(data);
      } else {
        return _buildGenericChart(data);
      }
    } catch (e) {
      print('Chart rendering error: $e');
      return Center(child: Text('Error rendering chart: $e'));
    }
  }

  Widget _buildPieChart(Map<String, dynamic> data) {
    // Extract labels and values
    final labels = data['labels'] is List ? data['labels'] : [];
    final values = data['values'] is List ? data['values'] : [];

    if (labels.isEmpty || values.isEmpty) {
      return const Center(child: Text('No pie chart data available'));
    }

    List<PieChartSectionData> sections = [];

    for (int i = 0; i < labels.length; i++) {
      sections.add(
        PieChartSectionData(
          color: i % 2 == 0 ? Colors.lightBlue.shade100 : Colors.white,
          value: (values[i] is num) ? values[i].toDouble() : 0.0,
          title: labels[i].toString(),
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              // Optional: Handle touch events
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<String, dynamic> data) {
    // Debugging print
    print('Line Chart Data: $data');

    // Check if data has 'labels' and 'values'
    final labels = data['labels'] is List ? data['labels'] : [];
    final values = data['values'] is List ? data['values'] : [];

    if (labels.isEmpty || values.isEmpty) {
      return const Center(child: Text('No line chart data available'));
    }

    List<LineChartBarData> lineBars = [
      LineChartBarData(
        isCurved: true,
        color: Colors.blue,
        barWidth: 4,
        isStrokeCapRound: true,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(show: true),
        spots: List.generate(
            values.length,
                (index) => FlSpot(
                index.toDouble(),
                (values[index] is num) ? values[index].toDouble() : 0.0
            )
        ),
      )
    ];

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  // Use labels for x-axis if available
                  final index = value.toInt();
                  return index >= 0 && index < labels.length
                      ? Text(labels[index].toString())
                      : const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: lineBars,
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> data) {
    // Implement bar chart similar to line chart
    final labels = data['labels'] is List ? data['labels'] : [];
    final values = data['values'] is List ? data['values'] : [];

    if (labels.isEmpty || values.isEmpty) {
      return const Center(child: Text('No bar chart data available'));
    }

    List<BarChartGroupData> barGroups = List.generate(
        values.length,
            (index) => BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: (values[index] is num) ? values[index].toDouble() : 0.0,
              color: Colors.lightBlue.shade100,
            )
          ],
        )
    );

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          barGroups: barGroups,
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  return index >= 0 && index < labels.length
                      ? Text(labels[index].toString())
                      : const Text('');
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenericChart(Map<String, dynamic> data) {
    // Fallback generic chart representation
    return Column(
      children: data.entries.map((entry) {
        return ListTile(
          title: Text(entry.key),
          trailing: Text(entry.value.toString()),
        );
      }).toList(),
    );
  }
}