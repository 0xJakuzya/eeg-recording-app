// widget for displaying the power line chart
// uses fl_chart for the chart
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';


class FFTDataPoint {
  final double amplitude;
  final double frequency;
  FFTDataPoint({required this.amplitude, required this.frequency});
}

// widget for displaying the power line chart
class PowerLineChart extends StatelessWidget {
  final List<List<FFTDataPoint>> channelData;
  const PowerLineChart({
    Key? key,
    required this.channelData,
})  : assert(channelData.length == 1, "Provide data for 1 channel."),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    // get the single channel data
    final List<FFTDataPoint> channel = channelData[0];
    final List<FlSpot> spots = channel.map((point) => FlSpot(point.frequency, pow(point.amplitude, 2).toDouble())).toList();
    final LineChartBarData lineBarData = LineChartBarData(
      spots: spots,
      isCurved: true,
      color: Colors.blue,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      barWidth: 2,
    );

    // build the LineChart widget 
    return Container(
      padding: const EdgeInsets.all(8),
      child: LineChart(
          LineChartData(
            lineBarsData: [lineBarData],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 10,
                  getTitlesWidget: (value, meta) {
                    return Text(value.toStringAsFixed(0));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: 10,
                  getTitlesWidget: (value, meta) {
                    return Text(value.toStringAsFixed(0));
                  },
                ),
              ),
            ),
            gridData: FlGridData(show: true),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                left: BorderSide(),
                bottom: BorderSide(),
              ),
            ),
            // Optionally, set axis ranges if needed:
            // minX: 0, maxX: 100,
            // minY: 0, maxY: 100,
          ),
        ),
    );
  }
}
