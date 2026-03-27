import 'package:flutter/material.dart';
import 'package:ble_app/core/theme/app_theme.dart';

// chart point: time in seconds and amplitude in volts
class EegDataPoint {
  final double time;
  final double amplitude;
  const EegDataPoint({required this.time, required this.amplitude});
}

// single-channel line chart rendered via CustomPainter
class EegLineChart extends StatelessWidget {
  final List<EegDataPoint> channelData;
  final List<EegDataPoint> persistedData;
  final double windowSeconds;
  final double amplitudeScale;
  final double displayRange;

  const EegLineChart({
    super.key,
    required this.channelData,
    this.persistedData = const [],
    required this.windowSeconds,
    this.amplitudeScale = 1.0,
    required this.displayRange,
  });

  @override
  Widget build(BuildContext context) {
    if (channelData.isEmpty && persistedData.isEmpty) {
      return Center(
        child: Text(
          'Нет данных',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return SizedBox.expand(
      child: CustomPaint(
        painter: EegWaveformPainter(
          channelData: channelData,
          persistedData: persistedData,
          windowSeconds: windowSeconds <= 0 ? 1.0 : windowSeconds,
          amplitudeScale: amplitudeScale,
          displayRange: displayRange,
        ),
      ),
    );
  }
}

class EegWaveformPainter extends CustomPainter {
  final List<EegDataPoint> channelData;
  final List<EegDataPoint> persistedData;
  final double windowSeconds;
  final double amplitudeScale;
  final double displayRange;

  // plot margins (space for axis labels)
  static const double marginLeft = 52.0;
  static const double marginRight = 8.0;
  static const double marginTop = 8.0;
  static const double marginBottom = 28.0;

  // Y axis range (normalized amplitude after scale)
  static const double yMin = -1.5;
  static const double yMax = 1.5;
  static const double yRange = yMax - yMin;

  // grid
  static const List<double> yGridLines = [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5];
  static const int xDivisions = 5;

  // rendering
  static const double signalStrokeWidth = 1.5;
  static const double gridStrokeWidth = 0.5;
  static const double borderStrokeWidth = 1.0;
  static const double labelFontSize = 10.0;
  static const double labelPadding = 4.0;
  static const double persistedAlpha = 0.45;

  const EegWaveformPainter({
    required this.channelData,
    required this.persistedData,
    required this.windowSeconds,
    required this.amplitudeScale,
    required this.displayRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotLeft = marginLeft;
    final plotTop = marginTop;
    final plotRight = size.width - marginRight;
    final plotBottom = size.height - marginBottom;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    final gridPaint = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = gridStrokeWidth;

    final borderPaint = Paint()
      ..color = AppTheme.borderSubtle
      ..strokeWidth = borderStrokeWidth
      ..style = PaintingStyle.stroke;

    // ── horizontal grid lines + Y labels ─────────────────────────────────────
    for (final yVal in yGridLines) {
      final py = plotTop + (1.0 - (yVal - yMin) / yRange) * plotHeight;
      canvas.drawLine(Offset(plotLeft, py), Offset(plotRight, py), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: yVal.toStringAsFixed(1),
          style: const TextStyle(fontSize: labelFontSize, color: AppTheme.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(plotLeft - tp.width - labelPadding, py - tp.height / 2));
    }

    // ── vertical grid lines + X labels ───────────────────────────────────────
    for (int i = 0; i <= xDivisions; i++) {
      final px = plotLeft + (i / xDivisions) * plotWidth;
      canvas.drawLine(Offset(px, plotTop), Offset(px, plotBottom), gridPaint);

      final timeVal = (i / xDivisions) * windowSeconds;
      final tp = TextPainter(
        text: TextSpan(
          text: timeVal.toStringAsFixed(0),
          style: const TextStyle(fontSize: labelFontSize, color: AppTheme.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, plotBottom + labelPadding));
    }

    // ── plot border ───────────────────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom), borderPaint);

    // ── clip signal traces to the plot area ───────────────────────────────────
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plotLeft, plotTop, plotRight, plotBottom));

    if (persistedData.isNotEmpty) {
      drawTrace(
        canvas,
        persistedData,
        plotLeft,
        plotTop,
        plotWidth,
        plotHeight,
        Colors.grey.shade400.withValues(alpha: persistedAlpha),
      );
    }

    if (channelData.isNotEmpty) {
      drawTrace(
        canvas,
        channelData,
        plotLeft,
        plotTop,
        plotWidth,
        plotHeight,
        AppTheme.eegSignalColor,
      );
    }

    canvas.restore();
  }

  void drawTrace(
    Canvas canvas,
    List<EegDataPoint> points,
    double plotLeft,
    double plotTop,
    double plotWidth,
    double plotHeight,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = signalStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool first = true;

    for (final point in points) {
      final x = plotLeft + (point.time / windowSeconds).clamp(0.0, 1.0) * plotWidth;
      final normAmp = (amplitudeScale * point.amplitude / displayRange).clamp(yMin, yMax);
      final y = plotTop + (1.0 - (normAmp - yMin) / yRange) * plotHeight;

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(EegWaveformPainter old) =>
      old.channelData != channelData ||
      old.persistedData != persistedData ||
      old.windowSeconds != windowSeconds ||
      old.amplitudeScale != amplitudeScale ||
      old.displayRange != displayRange;
}
