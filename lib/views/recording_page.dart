import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/controllers/recording_controller.dart';
import 'package:ble_app/utils/extension.dart';
import 'package:ble_app/widgets/eeg_plots.dart';
import 'package:ble_app/widgets/recording_status_card.dart';

/// Интервал обновления графика при записи (≈20 FPS)
const Duration _chartUpdateInterval = Duration(milliseconds: 50);

// view for recording and visualizing eeg data
// displays real-time signal charts, recording controls
// allows starting/stopping recordings and adjusting time window and amplitude scale.
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});
  @override
  State<RecordingPage> createState() => RecordingPageState();
}

class RecordingPageState extends State<RecordingPage> {

  final SettingsController settingsController = Get.find<SettingsController>();
  final RecordingController recordingController = Get.find<RecordingController>();
  List<double> get windowOptionsSeconds => RecordingConstants.eegPaperWidthsMm
      .map((w) => w / RecordingConstants.eegSweepMmPerSec)
      .toList();
  final List<double> amplitudeScales = [0.5, 1.0, 2.0, 4.0, 8.0];

  int currentWindowIndex = 0;
  int currentAmplitudeIndex = 1;

  Timer? _chartUpdateTimer;

  @override
  void initState() {
    super.initState();
    ever(recordingController.isRecording, _onRecordingChanged);
    _onRecordingChanged(recordingController.isRecording.value);
  }

  void _onRecordingChanged(bool isRecording) {
    if (isRecording) {
      _chartUpdateTimer?.cancel();
      _chartUpdateTimer = Timer.periodic(_chartUpdateInterval, (_) {
        if (mounted && recordingController.isRecording.value) {
          setState(() {});
        }
      });
    } else {
      _chartUpdateTimer?.cancel();
      _chartUpdateTimer = null;
    }
  }

  @override
  void dispose() {
    _chartUpdateTimer?.cancel();
    super.dispose();
  }

  double get windowSeconds => windowOptionsSeconds[currentWindowIndex];
  double get windowPaperWidthMm =>
      windowSeconds * RecordingConstants.eegSweepMmPerSec;
  double get amplitudeScale => amplitudeScales[currentAmplitudeIndex];

  // build chart data: последние windowSeconds секунд, X = 0..windowSeconds
  List<List<EegDataPoint>> buildChartData() {
    final format = settingsController.dataFormat.value;
    final channelCount = format == DataFormat.int24Be
        ? 8
        : settingsController.channelCount.value;
    final sampleRateHz = settingsController.samplingRateHz.value;
    final sampleIntervalSec =
        sampleRateHz > 0 ? 1.0 / sampleRateHz : RecordingConstants.sampleIntervalSeconds;
    final buffer = recordingController.realtimeBuffer;
    const maxPoints = RecordingConstants.eegChartMaxDisplayPoints;
    if (buffer.isEmpty) return <List<EegDataPoint>>[];
    final n = buffer.length;
    final windowSamples = (windowSeconds / sampleIntervalSec).ceil().clamp(1, n);
    final minIdx = (n - windowSamples).clamp(0, n - 1);
    final visibleCount = n - minIdx;
    final indices = <int>[];
    if (visibleCount <= maxPoints) {
      for (int i = minIdx; i < n; i++) indices.add(i);
    } else {
      for (int i = 0; i < maxPoints; i++) {
        final offset = (i * (visibleCount - 1) / (maxPoints - 1))
            .round()
            .clamp(0, visibleCount - 1);
        indices.add(minIdx + offset);
      }
      if (indices.last != n - 1) indices[indices.length - 1] = n - 1;
    }
    return List.generate(channelCount, (ch) {
      return indices.map((srcIdx) {
        final time = (srcIdx - minIdx) * sampleIntervalSec;
        final sample = buffer[srcIdx];
        final amplitude =
            ch < sample.channels.length ? sample.channels[ch] : 0.0;
        return EegDataPoint(time: time, amplitude: amplitude);
      }).toList();
    });
  }
  // start or stop recording
  Future<void> toggleRecording() async {
    if (recordingController.isRecording.value) {
      await recordingController.stopRecording();
    } else {
      await recordingController.startRecording();
    }
  }
  // cycle time window
  void cycleTimeWindow() {
    setState(() {
      currentWindowIndex =
          (currentWindowIndex + 1) % windowOptionsSeconds.length;
    });
  }
  // cycle amplitude scale
  void cycleAmplitudeScale() {
    setState(() {
      currentAmplitudeIndex =
          (currentAmplitudeIndex + 1) % amplitudeScales.length;
    });
  }
  @override
  Widget build(BuildContext context) {
    final format = settingsController.dataFormat.value;
    final channelCount = format == DataFormat.int24Be
        ? 8
        : settingsController.channelCount.value;
    final displayRange = format == DataFormat.int24Be
        ? RecordingConstants.eegChartDisplayRangeVolts
        : format.displayRange;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Запись ($channelCount каналов)',
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
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                              label: Text(
                                'Окно ${windowSeconds.toStringAsFixed(0)}',
                              ),
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
                    Container(
                      height: 450,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.02),
                      ),
                      child: EegLineChart(
                        channelData: buildChartData(),
                        windowSeconds: windowSeconds,
                        amplitudeScale: amplitudeScale,
                        displayRange: displayRange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => ElevatedButton.icon(
                  onPressed: toggleRecording,
                  icon: Icon(
                    recordingController.isRecording.value
                        ? Icons.stop
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    recordingController.isRecording.value
                        ? 'Остановить запись'
                        : 'Начать запись',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: recordingController.isRecording.value
                        ? Colors.redAccent
                        : Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}