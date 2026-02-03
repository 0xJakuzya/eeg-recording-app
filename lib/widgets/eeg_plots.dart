// widget for displaying eeg line chart
// supports 1-8 channels

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EegDataPoint {
  final double time;      
  final double amplitude; 
  EegDataPoint({required this.time, required this.amplitude});
}

// colors for channels
const List<Color> channelColors = [
  Colors.red,
  Colors.orange,
  Colors.yellow,
  Colors.green,
  Colors.cyan,
  Colors.blue,
  Colors.purple,
  Colors.pink,
];

class EegLineChart extends StatelessWidget {

  final List<List<EegDataPoint>> channelData; 
  final Set<int> visibleChannels;

  const EegLineChart({
    super.key,
    required this.channelData,
    required this.visibleChannels,
  });

  @override
  Widget build(BuildContext context) {

    final int numChannels = channelData.length;
    final List<LineChartBarData> lineBarsData = [];
    
    for (int ch = 0; ch < numChannels; ch++) {
      if (!visibleChannels.contains(ch)) continue;
      
      final spots = channelData[ch].map((point) => FlSpot(point.time, point.amplitude)).toList();
      lineBarsData.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: channelColors[ch % channelColors.length],
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        barWidth: 1.5,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          lineBarsData: lineBarsData,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Время (с)', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 2, // 10s graph every 2 seconds
                getTitlesWidget: (value, meta) {
                  return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('мкВ', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(),
              bottom: BorderSide(),
            ),
          ),
        ),
      ),
    );
  }
}

// legend widget for selecting channels
class ChannelLegend extends StatelessWidget {

  final int channelCount;
  final Set<int> visibleChannels;
  final Function(int) onToggle;

  const ChannelLegend({
    super.key,
    required this.channelCount,
    required this.visibleChannels,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: List.generate(channelCount, (index) {
        final isVisible = visibleChannels.contains(index);
        final color = channelColors[index % channelColors.length];
        return FilterChip(
          label: Text('CH${index + 1}'),
          selected: isVisible,
          onSelected: (_) => onToggle(index),
          selectedColor: color.withValues(alpha: 0.3),
          checkmarkColor: color,
          labelStyle: TextStyle(
            color: isVisible ? color : Colors.grey,
            fontWeight: isVisible ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }),
    );
  }
}
