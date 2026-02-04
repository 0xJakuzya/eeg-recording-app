import 'package:flutter/material.dart';

/// card showing recording status (icon + text)
class RecordingStatusCard extends StatelessWidget {
  final bool isRecording;

  const RecordingStatusCard({super.key, required this.isRecording});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecording ? Icons.fiber_manual_record : Icons.stop_circle,
              color: isRecording ? Colors.red : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isRecording ? 'Идет запись' : 'Запись остановлена',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
