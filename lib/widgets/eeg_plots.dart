// widget for displaying eeg line chart
// supports 1-8 channels

import 'dart:math' as math;

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
  final double windowSeconds;

  const EegLineChart({
    super.key,
    required this.channelData,
    required this.visibleChannels,
    required this.windowSeconds,
  });

  @override
  Widget build(BuildContext context) {

    final int numChannels = channelData.length;

    final List<int> visibleList = visibleChannels
        .where((ch) => ch >= 0 && ch < numChannels)
        .toList()
      ..sort();

    if (visibleList.isEmpty) {
      return const Center(child: Text('Нет выбранных каналов'));
    }

    final Map<int, double> channelMaxAbs = {};
    for (final ch in visibleList) {
      double maxAbs = 0;
      for (final point in channelData[ch]) {
        maxAbs = math.max(maxAbs, point.amplitude.abs());
      }
      channelMaxAbs[ch] = maxAbs == 0 ? 1 : maxAbs;
    }


    const double channelStep = 2.0;
    const double halfHeight = 0.8; 

    final List<LineChartBarData> lineBarsData = [];

    double maxTime = 0;
    final firstChannelPoints = channelData[visibleList.first];
    if (firstChannelPoints.isNotEmpty) {
      maxTime = firstChannelPoints.last.time;
    }
    final double effectiveWindow = windowSeconds <= 0 ? 1.0 : windowSeconds;
    final double minWindowTime = (maxTime - effectiveWindow).clamp(0, maxTime);

    for (int order = 0; order < visibleList.length; order++) {
      final int ch = visibleList[order];
      final double centerY = order * channelStep;
      final double maxAbs = channelMaxAbs[ch]!;

      final spots = channelData[ch]
          .where((point) => point.time >= minWindowTime)
          .map(
            (point) => FlSpot(
              point.time - minWindowTime,
              centerY + (point.amplitude / maxAbs) * halfHeight,
            ),
          )
          .toList();

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: channelColors[ch % channelColors.length],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          barWidth: 1.5,
        ),
      );
    } 
    final Map<double, String> yLabels = {};
    for (int order = 0; order < visibleList.length; order++) {
      final int ch = visibleList[order];
      final double centerY = order * channelStep;
      yLabels[centerY] = 'CH${ch + 1}';
    }

    final double minY = -channelStep;
    final double maxY = (visibleList.length - 1) * channelStep + channelStep;

    final double minX = 0;
    final double maxX = effectiveWindow;

    return Container(
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          lineBarsData: lineBarsData,
          minY: minY,
          maxY: maxY,
          minX: minX,
          maxX: maxX,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Время (с)', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxX / 5).clamp(0.5, double.infinity),
                getTitlesWidget: (value, meta) {
                  return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Каналы', style: TextStyle(fontSize: 12)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  const double threshold = 0.4;
                  double? closestKey;
                  for (final key in yLabels.keys) {
                    if ((value - key).abs() < threshold) {
                      closestKey = key;
                      break;
                    }
                  }
                  if (closestKey == null) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    yLabels[closestKey]!,
                    style: const TextStyle(fontSize: 10),
                  );
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
