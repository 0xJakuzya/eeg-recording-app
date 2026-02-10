import 'package:flutter/material.dart';

// card showing recording status and current/last saved file path
class RecordingStatusCard extends StatelessWidget {
  final bool isRecording;
  final String? filePath;

  const RecordingStatusCard({
    super.key,
    required this.isRecording,
    this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final String? displayPath;
    if (filePath != null && filePath!.isNotEmpty) {
      final segments = filePath!
          .split(RegExp(r'[\\/]+'))
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.length >= 3) {
        displayPath =
            segments.sublist(segments.length - 3).join(' / ');
      } else {
        displayPath = segments.join(' / ');
      }
    } else {
      displayPath = null;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRecording ? Icons.fiber_manual_record : Icons.stop_circle,
                  color: isRecording ? Colors.red : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isRecording ? 'Идёт запись' : 'Запись остановлена',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (displayPath != null && displayPath.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Файл: $displayPath',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
