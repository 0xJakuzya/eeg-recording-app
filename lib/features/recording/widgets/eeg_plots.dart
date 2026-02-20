import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ble_app/core/theme/app_theme.dart';

/// EEG line chart widget. Supports 1-8 channels.
class EegDataPoint {
  final double time;
  final double amplitude;
  EegDataPoint({required this.time, required this.amplitude});
}

class EegLineChart extends StatelessWidget {
  final List<List<EegDataPoint>> channelData;
  /// Зафиксированный след (отображается блекло)
  final List<List<EegDataPoint>> persistedChannelData;
  final double windowSeconds;
  final double amplitudeScale;
  final double displayRange;

  const EegLineChart({
    super.key,
    required this.channelData,
    this.persistedChannelData = const [],
    required this.windowSeconds,
    this.amplitudeScale = 1.0,
    required this.displayRange,
  });

  @override
  Widget build(BuildContext context) {
    final int numChannels = channelData.isNotEmpty
        ? channelData.length
        : persistedChannelData.length;
    if (numChannels == 0) {
      return Center(
        child: Text(
          'Нет данных',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    const mutedTextStyle = TextStyle(
      fontSize: 10,
      color: AppTheme.textSecondary,
    );

    final List<int> channelIndices =
        List<int>.generate(numChannels, (index) => index);

    const double channelStep = 3.0;
    const double halfHeight = 0.7;
    final double effectiveWindow = windowSeconds <= 0 ? 1.0 : windowSeconds;
    final double maxX = effectiveWindow;

    final List<LineChartBarData> lineBarsData = [];
    final persistedColor = Colors.grey.shade400;

    for (int order = 0; order < channelIndices.length; order++) {
      final int ch = channelIndices[order];
      final double centerY = order * channelStep;
      final double range = displayRange;

      final maxCurrentX = ch < channelData.length && channelData[ch].isNotEmpty
          ? channelData[ch]
              .map((p) => p.time)
              .fold(0.0, (a, b) => a > b ? a : b)
          : 0.0;

      if (ch < persistedChannelData.length &&
          persistedChannelData[ch].isNotEmpty) {
        final persistedSpots = persistedChannelData[ch]
            .where((p) => p.time > maxCurrentX && p.time <= effectiveWindow)
            .map((point) {
          final norm = (point.amplitude / range).clamp(-1.0, 1.0);
          final x = point.time.clamp(0.0, effectiveWindow);
          return FlSpot(
            x,
            centerY + amplitudeScale * norm * halfHeight,
          );
        }).toList();
        lineBarsData.add(
          LineChartBarData(
            spots: persistedSpots,
            isCurved: true,
            color: persistedColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            barWidth: 1.0,
          ),
        );
      }

      final currentSpots =
          ch < channelData.length && channelData[ch].isNotEmpty
              ? channelData[ch]
                  .where((p) => p.time >= 0 && p.time <= effectiveWindow)
                  .map((point) {
                  final norm = (point.amplitude / range).clamp(-1.0, 1.0);
                  final x = point.time.clamp(0.0, effectiveWindow);
                  return FlSpot(
                    x,
                    centerY + amplitudeScale * norm * halfHeight,
                  );
                }).toList()
              : <FlSpot>[];

      final channelColor =
          AppTheme.eegChannelColors[ch % AppTheme.eegChannelColors.length];

      lineBarsData.add(
        LineChartBarData(
          spots: currentSpots,
          isCurved: true,
          curveSmoothness: 0.1,
          color: channelColor,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
          barWidth: 1.0,
        ),
      );
    }

    final Map<double, String> yLabels = {};
    for (int order = 0; order < channelIndices.length; order++) {
      final int ch = channelIndices[order];
      final double centerY = order * channelStep;
      yLabels[centerY] = 'CH ${ch + 1}';
    }

    final double minY = -channelStep;
    final double maxY =
        (channelIndices.length - 1) * channelStep + channelStep;

    return Container(
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: lineBarsData,
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: maxX,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Время (с)',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (maxX / 5).clamp(0.5, double.infinity),
                getTitlesWidget: (value, meta) =>
                    Text(value.toStringAsFixed(0), style: mutedTextStyle),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Каналы',
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                  if (closestKey == null) return const SizedBox.shrink();
                  return Text(yLabels[closestKey]!, style: mutedTextStyle);
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.gridLine, strokeWidth: 0.5),
            getDrawingVerticalLine: (_) =>
                FlLine(color: AppTheme.gridLine, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: AppTheme.borderSubtle),
              bottom: BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
        ),
        duration: Duration.zero,
      ),
    );
  }
}
