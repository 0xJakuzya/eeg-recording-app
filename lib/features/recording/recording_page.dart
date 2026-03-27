import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/core/utils/lttb.dart';
import 'package:ble_app/features/recording/recording_controller.dart';
import 'package:ble_app/features/recording/widgets/eeg_plots.dart';
import 'package:ble_app/features/recording/widgets/recording_status_card.dart';

const Duration chartUpdateInterval = Duration(milliseconds: 50);

// page responsible for live EEG recording and real-time chart display
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => RecordingPageState();
}

class RecordingPageState extends State<RecordingPage> {
  final RecordingController recordingController = Get.find<RecordingController>();

  List<double> get windowOptionsSeconds => RecordingConstants.eegPaperWidthsMm
      .map((w) => w / RecordingConstants.eegSweepMmPerSec)
      .toList();
  final List<double> amplitudeScales = [0.5, 1.0, 2.0, 4.0, 8.0];

  int currentWindowIndex = 2;
  int currentAmplitudeIndex = 1;

  Timer? chartUpdateTimer;
  final ValueNotifier<List<EegDataPoint>> chartDataNotifier = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    ever(recordingController.isRecording, onRecordingStateChanged);
    onRecordingStateChanged(recordingController.isRecording.value);
  }

  void onRecordingStateChanged(bool recording) {
    chartUpdateTimer?.cancel();
    if (recording) {
      chartDataNotifier.value = buildChartData();
      chartUpdateTimer = Timer.periodic(chartUpdateInterval, (timer) {
        if (mounted && recordingController.isRecording.value) {
          chartDataNotifier.value = buildChartData();
        }
      });
    } else {
      chartDataNotifier.value = [];
      chartUpdateTimer = null;
    }
  }

  @override
  void dispose() {
    chartUpdateTimer?.cancel();
    chartDataNotifier.dispose();
    super.dispose();
  }

  double get windowSeconds => windowOptionsSeconds[currentWindowIndex];
  double get amplitudeScale => amplitudeScales[currentAmplitudeIndex];

  // Returns raw visible-window samples; downsampling happens at render time via LTTB.
  List<EegDataPoint> buildChartData() {
    final buffer = recordingController.realtimeBuffer;
    if (buffer.isEmpty) return [];

    final n = buffer.length;
    final windowSamples =
        (windowSeconds / RecordingConstants.sampleIntervalSeconds).ceil().clamp(1, n);
    final minIdx = (n - windowSamples).clamp(0, n - 1);

    return List.generate(
      n - minIdx,
      (i) => EegDataPoint(
        time: i * RecordingConstants.sampleIntervalSeconds,
        amplitude: buffer[minIdx + i].volts,
      ),
    );
  }

  Future<void> toggleRecording() async {
    if (recordingController.isRecording.value) {
      await recordingController.stopRecording();
    } else {
      await recordingController.startRecording();
    }
  }

  void cycleTimeWindow() {
    setState(() {
      currentWindowIndex = (currentWindowIndex + 1) % windowOptionsSeconds.length;
    });
  }

  void cycleAmplitudeScale() {
    setState(() {
      currentAmplitudeIndex = (currentAmplitudeIndex + 1) % amplitudeScales.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    const displayRange = RecordingConstants.eegChartDisplayRangeVolts;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Запись ЭЭГ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() => RecordingStatusCard(
                  isRecording: recordingController.isRecording.value,
                  filePath: recordingController.currentFilePath.value,
                )),
            Obx(() {
              final flat = recordingController.isChannelSignalFlat.value;
              final recording = recordingController.isRecording.value;
              if (!flat || !recording) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusWarning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.statusWarning.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.statusWarning, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Плоский сигнал. Проверьте подключение электрода.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'График сигнала',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: cycleTimeWindow,
                            icon: const Icon(Icons.speed),
                            label: Text('Окно ${windowSeconds.toStringAsFixed(0)}с'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: cycleAmplitudeScale,
                            icon: const Icon(Icons.stacked_line_chart),
                            label: Text('Ампл x${amplitudeScale.toStringAsFixed(1)}'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 450,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxPoints =
                            (constraints.maxWidth * RecordingConstants.eegChartPointsPerPixel)
                                .toInt()
                                .clamp(
                                  RecordingConstants.eegChartMinDisplayPoints,
                                  RecordingConstants.eegChartMaxDisplayPoints,
                                );
                        return ValueListenableBuilder<List<EegDataPoint>>(
                          valueListenable: chartDataNotifier,
                          builder: (context, data, child) => EegLineChart(
                            channelData: lttbDownsample(
                              data: data,
                              threshold: maxPoints,
                              getX: (p) => p.time,
                              getY: (p) => p.amplitude,
                            ),
                            windowSeconds: windowSeconds,
                            amplitudeScale: amplitudeScale,
                            displayRange: displayRange,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final preparing = recordingController.isPreparing.value;
              final recording = recordingController.isRecording.value;
              return ElevatedButton.icon(
                onPressed: preparing ? null : toggleRecording,
                icon: preparing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textPrimary,
                        ),
                      )
                    : Icon(recording ? Icons.stop : Icons.play_arrow),
                label: Text(
                  preparing
                      ? 'Отправка команд...'
                      : recording
                          ? 'Остановить запись'
                          : 'Начать запись',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: preparing
                      ? AppTheme.accentPrimary.withValues(alpha: 0.5)
                      : recording
                          ? AppTheme.statusRecording
                          : AppTheme.accentPrimary,
                  foregroundColor: AppTheme.textPrimary,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
