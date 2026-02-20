import 'package:flutter/material.dart';
import 'package:ble_app/core/theme/app_theme.dart';

// recording status card; file path shortened to last 3 path segments
class RecordingStatusCard extends StatelessWidget {
  const RecordingStatusCard({
    super.key,
    required this.isRecording,
    this.filePath,
  });

  final bool isRecording;
  final String? filePath;

  static String? formatFilePathForDisplay(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    final segments = filePath
        .split(RegExp(r'[\\/]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.length >= 3) {
      return segments.sublist(segments.length - 3).join(' / ');
    }
    return segments.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final displayPath = formatFilePathForDisplay(filePath);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: isRecording
            ? [
                BoxShadow(
                  color: AppTheme.statusRecording.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RecordingIndicator(isRecording: isRecording),
              const SizedBox(width: 8),
              Text(
                isRecording ? 'Идёт запись' : 'Запись остановлена',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
          if (displayPath != null && displayPath.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Файл: $displayPath',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// scale animation when recording, static stop icon when not
class RecordingIndicator extends StatefulWidget {
  const RecordingIndicator({required this.isRecording});

  final bool isRecording;

  @override
  State<RecordingIndicator> createState() => RecordingIndicatorState();
}

class RecordingIndicatorState extends State<RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    scaleAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    );
    if (widget.isRecording) {
      animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      animationController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      animationController.stop();
      animationController.reset();
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) {
      return Icon(
        Icons.stop_circle,
        color: AppTheme.textMuted,
        size: 24,
      );
    }
    return ScaleTransition(
      scale: scaleAnimation,
      child: Icon(
        Icons.fiber_manual_record,
        color: AppTheme.statusRecording,
        size: 24,
      ),
    );
  }
}
