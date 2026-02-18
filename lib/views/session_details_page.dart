import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ble_app/core/polysomnography_constants.dart';
import 'package:ble_app/models/processed_session_models.dart';
import 'package:ble_app/services/polysomnography_service.dart';

/// Загружает гипнограмму через PolysomnographyApiService.
class HypnogramImage extends StatefulWidget {
  const HypnogramImage({
    super.key,
    required this.service,
    required this.index,
  });

  final PolysomnographyApiService service;
  final int index;

  @override
  State<HypnogramImage> createState() => HypnogramImageState();
}

class HypnogramImageState extends State<HypnogramImage> {
  late final Future<List<int>> imageLoadFuture;

  @override
  void initState() {
    super.initState();
    imageLoadFuture = widget.service.fetchSleepGraphImage(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: imageLoadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
            const Text('Ошибка загрузки гипнограммы'),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
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

class SessionDetailsPage extends StatelessWidget {
  const SessionDetailsPage({
    super.key,
    required this.session,
  });

  final ProcessedSession session;

  static final PolysomnographyApiService polysomnographyService =
      PolysomnographyApiService(
    baseUrl: PolysomnographyConstants.defaultBaseUrl,
  );

  @override
  Widget build(BuildContext context) {
    final prediction = session.prediction;

    // sleep_graph: GET /users/sleep_graph?index=N (0-based)
    int? sleepGraphIndex;
    if (session.jsonIndex != null) {
      sleepGraphIndex = (session.jsonIndex! - 1).clamp(0, 999999);
    }

    final hypnogramWidget = sleepGraphIndex != null
        ? HypnogramImage(
            service: polysomnographyService,
            index: sleepGraphIndex,
          )
        : null;

    if (prediction == null || prediction.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Сессия ${session.id}'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hypnogramWidget != null)
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Гипнограмма',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: hypnogramWidget,
                      ),
                    ],
                  ),
                ),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Данных предикта для этой сессии пока нет'),
                ),
              ),
          ],
        ),
      );
    }

    final List<Widget> children = <Widget>[];

    if (hypnogramWidget != null) {
      children.add(
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Гипнограмма',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: hypnogramWidget,
                ),
              ],
            ),
          ),
        ),
      );
    }

    children.addAll(
      prediction.entries.map((entry) {
        final stage = entry.key;
        final intervals = entry.value;

        final List<Widget> chips = <Widget>[];
        if (intervals is List) {
          for (final interval in intervals) {
            if (interval is List && interval.length >= 2) {
              final start = interval[0];
              final end = interval[1];
              chips.add(
                Chip(
                  label: Text('$start–$end с'),
                ),
              );
            }
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (chips.isEmpty)
                  const Text(
                    'Интервалы отсутствуют',
                    style: TextStyle(color: Colors.black54),
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
      appBar: AppBar(
        title: Text('Сессия ${session.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }
}
