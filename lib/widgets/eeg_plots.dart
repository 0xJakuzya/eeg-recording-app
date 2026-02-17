import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// widget for displaying eeg line chart
// supports 1-8 channels
class EegDataPoint {
  final double time;
  final double amplitude;
  EegDataPoint({required this.time, required this.amplitude});
}

class EegLineChart extends StatelessWidget {
  final List<List<EegDataPoint>> channelData;
  final double windowSeconds;
  final double amplitudeScale;
  final double displayRange;

  const EegLineChart({
    super.key,
    required this.channelData,
    required this.windowSeconds,
    this.amplitudeScale = 1.0,
    required this.displayRange,
  });

  @override
  Widget build(BuildContext context) {
    final int numChannels = channelData.length;
    if (numChannels == 0) {
      return const Center(child: Text('Нет данных'));
    }

    final List<int> channelIndices =
        List<int>.generate(numChannels, (index) => index);

    const double channelStep = 3.0;
    const double halfHeight = 0.7;
    final double effectiveWindow = windowSeconds <= 0 ? 1.0 : windowSeconds;
    final double maxX = effectiveWindow;

    final List<LineChartBarData> lineBarsData = [];

    for (int order = 0; order < channelIndices.length; order++) {
      final int ch = channelIndices[order];
      final double centerY = order * channelStep;
      final double range = displayRange;

      final spots = channelData[ch].map((point) {
        final norm = (point.amplitude / range).clamp(-1.0, 1.0);
        final x = point.time.clamp(0.0, effectiveWindow);
        return FlSpot(
          x,
          centerY + amplitudeScale * norm * halfHeight,
        );
      }).toList();

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.1,
          color: Colors.black,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          barWidth: 0.8,
        ),
      );
    }
    // get the y labels
    final Map<double, String> yLabels = {};
    for (int order = 0; order < channelIndices.length; order++) {
      final int ch = channelIndices[order];
      final double centerY = order * channelStep;
      yLabels[centerY] = 'CH ${ch + 1}';
    }

    // get the min and max y
    final double minY = -channelStep;
    final double maxY = (channelIndices.length - 1) * channelStep + channelStep;

    final double minX = 0;

    // return the container
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
                interval: channelStep,
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