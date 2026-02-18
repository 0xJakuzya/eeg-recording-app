import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ble_app/core/polysomnography_constants.dart';
import 'package:ble_app/models/processed_session_models.dart';

/// Загружает гипнограмму через http.get и показывает детали при ошибке.
class _HypnogramImage extends StatefulWidget {
  const _HypnogramImage({required this.uri});

  final Uri uri;

  @override
  State<_HypnogramImage> createState() => _HypnogramImageState();
}

class _HypnogramImageState extends State<_HypnogramImage> {
  late final Future<http.Response> _future;

  @override
  void initState() {
    super.initState();
    _future = http.get(widget.uri);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<http.Response>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorContent(
            uri: widget.uri.toString(),
            message: '${snapshot.error}',
          );
        }
        final response = snapshot.data!;
        if (response.statusCode != 200) {
          final body = response.body.length > 150
              ? '${response.body.substring(0, 150)}...'
              : response.body;
          return _ErrorContent(
            uri: widget.uri.toString(),
            message: 'HTTP ${response.statusCode}\n$body',
          );
        }
        final bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          return _ErrorContent(
            uri: widget.uri.toString(),
            message: 'Пустой ответ',
          );
        }
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _ErrorContent(
            uri: widget.uri.toString(),
            message: 'Не удалось декодировать изображение: $error',
          ),
        );
      },
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.uri, required this.message});

  final String uri;
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
            const SizedBox(height: 4),
            Text(
              uri,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
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

  @override
  Widget build(BuildContext context) {
    final prediction = session.prediction;

    // sleep_graph: GET /users/sleep_graph?index=0 (0-based)
    Uri? sleepGraphUri;
    if (session.jsonIndex != null) {
      final idx = (session.jsonIndex! - 1).clamp(0, 999999);
      sleepGraphUri = Uri.parse(
              '${PolysomnographyConstants.defaultBaseUrl}${PolysomnographyConstants.sleepGraphPath}')
          .replace(
        queryParameters: <String, String>{'index': idx.toString()},
      );
    }

    if (prediction == null || prediction.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Сессия ${session.id}'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (sleepGraphUri != null) ...[
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
                        child: _HypnogramImage(uri: sleepGraphUri),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
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

    if (sleepGraphUri != null) {
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
                  child: _HypnogramImage(uri: sleepGraphUri),
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
