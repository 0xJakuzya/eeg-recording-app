import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/features/polysomnography/polysomnography_service.dart';

// parses [start, end] interval to seconds; returns 0 if invalid
double parseIntervalSeconds(List interval) {
  if (interval.length < 2) return 0;
  final start = (interval[0] is num
          ? interval[0] as num
          : num.tryParse(interval[0].toString()) ?? 0)
      .toDouble();
  final end = (interval[1] is num
          ? interval[1] as num
          : num.tryParse(interval[1].toString()) ?? 0)
      .toDouble();
  return end - start;
}

// sums interval durations per stage; keys are wake, n1, n2, n3, rem etc
Map<String, double> computeStageDurations(Map<String, dynamic> prediction) {
  final result = <String, double>{};
  for (final entry in prediction.entries) {
    double total = 0;
    if (entry.value is List) {
      for (final interval in entry.value as List) {
        if (interval is List && interval.length >= 2) {
          total += parseIntervalSeconds(interval);
        }
      }
    }
    result[entry.key] = total;
  }
  return result;
}

// pie chart from stage durations; shows percentage per stage
class SleepStagesPieChart extends StatelessWidget {
  const SleepStagesPieChart({super.key, required this.prediction});

  final Map<String, dynamic> prediction;

  @override
  Widget build(BuildContext context) {
    final durations = computeStageDurations(prediction);
    if (durations.isEmpty) {
      return const Center(
        child: Text(
          'Нет данных для диаграммы',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final total = durations.values.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      return const Center(
        child: Text(
          'Нет данных для диаграммы',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final sections = durations.entries
        .where((e) => e.value > 0)
        .map((e) {
          final pct = (e.value / total * 100).toStringAsFixed(1);
          return PieChartSectionData(
            value: e.value,
            title: '${e.key}\n$pct%',
            color: AppTheme.getStageColor(e.key),
            titleStyle: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            radius: 80,
            showTitle: true,
          );
        })
        .toList();

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 30,
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// fetches hypnogram bitmap from api; caches future, FutureBuilder for loading
class HypnogramImage extends StatefulWidget {
  const HypnogramImage({
    super.key,
    required this.service,
    required this.index,
    this.startFrom,
    this.endTo,
  });

  final PolysomnographyApiService service;
  final int index;
  final int? startFrom;
  final int? endTo;

  @override
  State<HypnogramImage> createState() => HypnogramImageState();
}

class HypnogramImageState extends State<HypnogramImage> {
  late final Future<List<int>> imageLoadFuture;

  // fetches image once in init; future reused by FutureBuilder
  @override
  void initState() {
    super.initState();
    imageLoadFuture = widget.service.fetchSleepGraphImage(
      widget.index,
      startFrom: widget.startFrom,
      endTo: widget.endTo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: imageLoadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppTheme.accentSecondary),
          );
        }
        if (snapshot.hasError) {
          return HypnogramErrorContent(message: '${snapshot.error}');
        }
        final bytes = snapshot.data!;
        if (bytes.isEmpty) {
          return const HypnogramErrorContent(message: 'Пустой ответ');
        }
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => HypnogramErrorContent(
            message: 'Не удалось декодировать изображение: $error',
          ),
        );
      },
    );
  }
}

// error message display when hypnogram load fails
class HypnogramErrorContent extends StatelessWidget {
  const HypnogramErrorContent({super.key, required this.message});

  final String message;

  // centered column: title + message; max 5 lines for message
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ошибка загрузки гипнограммы',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// card wrapper for hypnogram image with optional pie chart below
class HypnogramCard extends StatelessWidget {
  const HypnogramCard({
    super.key,
    required this.title,
    required this.child,
    this.pieChartWidget,
  });

  final String title;
  final Widget child;
  final Widget? pieChartWidget;

  // title, fixed-height child, optional divider and pie chart
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: child,
          ),
          if (pieChartWidget != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderSubtle),
            const SizedBox(height: 12),
            const Text(
              'Распределение стадий сна',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            pieChartWidget!,
          ],
        ],
      ),
    );
  }
}

// hypnogram + pie chart; handles missing prediction
class SessionDetailsPage extends StatelessWidget {
  const SessionDetailsPage({
    super.key,
    required this.fileName,
    required this.prediction,
    required this.jsonIndex,
    required this.service,
  });

  final String fileName;
  final Map<String, dynamic>? prediction;
  final int jsonIndex;
  final PolysomnographyApiService service;

  // hypnogram only when prediction missing; full card with pie when present
  @override
  Widget build(BuildContext context) {
    final pred = prediction;

    final hypnogramWidget =
        HypnogramImage(service: service, index: jsonIndex);

    if (pred == null || pred.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(fileName)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            HypnogramCard(title: 'Гипнограмма', child: hypnogramWidget),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Данных предикта для этого файла пока нет.\nСервер должен вернуть prediction в ответе save_predict_json.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HypnogramCard(
            title: 'Гипнограмма',
            child: hypnogramWidget,
            pieChartWidget: SleepStagesPieChart(prediction: pred!),
          ),
        ],
      ),
    );
  }
}
