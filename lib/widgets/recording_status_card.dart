import 'package:flutter/material.dart';
import 'package:ble_app/core/app_theme.dart';

/// Card showing recording status and current/last saved file path.
/// Dark theme with red glow when recording.
class RecordingStatusCard extends StatelessWidget {
  const RecordingStatusCard({
    super.key,
    required this.isRecording,
    this.filePath,
  });

  final bool isRecording;
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    final String? displayPath;
    if (filePath != null && filePath!.isNotEmpty) {
      final segments = filePath!
          .split(RegExp(r'[\\/]+'))
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.length >= 3) {
        displayPath = segments.sublist(segments.length - 3).join(' / ');
      } else {
        displayPath = segments.join(' / ');
      }
    } else {
      displayPath = null;
    }

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
              _RecordingIndicator(isRecording: isRecording),
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

/// Pulsing record indicator when recording, static when not.
class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator({required this.isRecording});

  final bool isRecording;

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_RecordingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
      scale: _scaleAnimation,
      child: Icon(
        Icons.fiber_manual_record,
        color: AppTheme.statusRecording,
        size: 24,
      ),
    );
  }
}
