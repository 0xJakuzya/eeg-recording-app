import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/features/polysomnography/polysomnography_service.dart';

Map<String, double> computeStageDurations(Map<String, dynamic> prediction) {
  final result = <String, double>{};
  for (final entry in prediction.entries) {
    double total = 0;
    if (entry.value is List) {
      for (final interval in entry.value as List) {
        if (interval is List && interval.length >= 2) {
          final start = (interval[0] is num
                  ? interval[0] as num
                  : num.tryParse(interval[0].toString()) ?? 0)
              .toDouble();
          final end = (interval[1] is num
                  ? interval[1] as num
                  : num.tryParse(interval[1].toString()) ?? 0)
              .toDouble();
          total += end - start;
        }
      }
    }
    result[entry.key] = total;
  }
  return result;
}

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

class HypnogramErrorContent extends StatelessWidget {
  const HypnogramErrorContent({super.key, required this.message});

  final String message;

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

class HypnogramCard extends StatelessWidget {
  const HypnogramCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

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
            height: MediaQuery.of(context).size.height * 0.4,
            child: child,
          ),
        ],
      ),
    );
  }
}

class SessionDetailsPage extends StatelessWidget {
  const SessionDetailsPage({
    super.key,
    required this.fileName,
    required this.prediction,
    required this.jsonIndex,
    required this.service,
    this.patientId,
    this.fileIndex,
  });

  final String fileName;
  final Map<String, dynamic>? prediction;
  final int jsonIndex;
  final PolysomnographyApiService service;
  final int? patientId;
  final int? fileIndex;

  @override
  Widget build(BuildContext context) {
    final pred = prediction;

    final hypnogramWidget =
        HypnogramImage(service: service, index: jsonIndex);

    final verificationCard = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Данные для проверки соответствия',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text('Файл: $fileName',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          if (patientId != null)
            Text('Пациент ID: $patientId',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          if (fileIndex != null)
            Text('Индекс файла: $fileIndex',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          Text(
            'Индекс sleep_graph: $jsonIndex (глобальный счётчик)',
            style: const TextStyle(color: AppTheme.accentSecondary, fontSize: 13),
          ),
        ],
      ),
    );

    if (pred == null || pred.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(fileName)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            verificationCard,
            HypnogramCard(title: 'Гипнограмма', child: hypnogramWidget),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Данных предикта для этого файла пока нет',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> children = <Widget>[
      verificationCard,
      HypnogramCard(
          title: 'Гипнограмма (индекс: $jsonIndex)', child: hypnogramWidget),
      Container(
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
            const Text(
              'Распределение стадий сна',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            SleepStagesPieChart(prediction: pred),
          ],
        ),
      ),
    ];

    children.addAll(
      pred.entries.map((entry) {
        final stage = entry.key;
        final intervals = entry.value;
        final stageColor = AppTheme.getStageColor(stage);

        final List<Widget> chips = <Widget>[];
        if (intervals is List) {
          for (final interval in intervals) {
            if (interval is List && interval.length >= 2) {
              final start = interval[0];
              final end = interval[1];
              chips.add(
                Chip(
                  label: Text('$start–$end с'),
                  backgroundColor: stageColor.withValues(alpha: 0.2),
                  side: BorderSide(color: stageColor.withValues(alpha: 0.5)),
                  labelStyle: const TextStyle(color: AppTheme.textPrimary),
                ),
              );
            }
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: stageColor.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage,
                  style: TextStyle(
                    color: stageColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (chips.isEmpty)
                  const Text(
                    'Интервалы отсутствуют',
                    style: TextStyle(color: AppTheme.textSecondary),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  ),
              ],
            ),
          ),
        );
      }),
    );

    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}
