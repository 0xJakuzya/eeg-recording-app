import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/controllers/recording_controller.dart';
import 'package:ble_app/widgets/eeg_plots.dart';
import 'package:ble_app/widgets/recording_status_card.dart';

// view for recording and visualizing eeg data
// displays real-time eeg signal charts, recording controls, and channel selection.
// allows starting/stopping recordings and adjusting time window and amplitude scale.
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => RecordingPageState();
}

class RecordingPageState extends State<RecordingPage> {

  final SettingsController settingsController = Get.find<SettingsController>(); // settings controller
  final RecordingController recordingController = Get.find<RecordingController>(); // recording controller

  final List<double> windowOptionsSeconds = [5.0, 10.0]; // time window 
  int currentWindowIndex = 0;
  final List<double> amplitudeScales = [1.0, 2.0, 4.0, 8.0]; // amplitude scale
  int currentAmplitudeIndex = 1;

  @override
  void initState() {
    super.initState();
  }

  double get windowSeconds => windowOptionsSeconds[currentWindowIndex];
  double get amplitudeScale => amplitudeScales[currentAmplitudeIndex];

  // build chart data from real-time buffer or demo data
  List<List<EegDataPoint>> buildChartData() {

    final channelCount = settingsController.channelCount.value; // channel count
    final buffer = recordingController.realtimeBuffer; // realtime buffer

    // if buffer is not empty, return chart data
    if (buffer.isNotEmpty) {
      return List.generate(channelCount, (ch) {
        return buffer.asMap().entries.map((entry) {
          final idx = entry.key;
          final sample = entry.value;
          // sample index * sample interval
          final time = idx * RecordingConstants.sampleIntervalSeconds;
          // if sample has values, take it, else - 0
          final amplitude =
              ch < sample.channels.length ? sample.channels[ch] : 0.0;
          // return time, ch-amplitude
          return EegDataPoint(time: time, amplitude: amplitude);
        }).toList();
      });
    }
    // return demo data if buffer is empty
    return buildDemoData();
  }
  
  // generate demo data for testing
  List<List<EegDataPoint>> buildDemoData() {
    final random = Random(42); // number generator
    final channelCount = settingsController.channelCount.value; 
    return List.generate(channelCount, (channel) {
      return List.generate(RecordingConstants.demoDataPointCount, (i) {
        final time = i * RecordingConstants.sampleIntervalSeconds; 
        final baseFreq = 5.0 + channel * 2; // frequency
        final amplitude = 50 *
                sin(2 * pi * baseFreq * time) +
            random.nextDouble() * 20 -
            10; // amplitude with noise
        return EegDataPoint(time: time, amplitude: amplitude); 
      });
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
    return Obx(() {
      final channelCount = settingsController.channelCount.value;
      final isRecording = recordingController.isRecording.value;
      final chartData = buildChartData();

      return Scaffold(
        appBar: AppBar(
          title: Text('Запись ЭЭГ ($channelCount каналов)'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // recording status card
              RecordingStatusCard(
                isRecording: isRecording,
                filePath: recordingController.currentFilePath.value,
              ),
              const SizedBox(height: 16),
              // eeg signal chart
              Card(
                color: const Color(0xFFFFF3B0),
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
                                label: Text('Окно ${windowSeconds.toStringAsFixed(0)} c'),
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
                          color: const Color(0xFFFFF3B0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: EegLineChart(
                          channelData: chartData,
                          windowSeconds: windowSeconds,
                          amplitudeScale: amplitudeScale,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // recording control button
              ElevatedButton.icon(
                onPressed: toggleRecording,
                icon: Icon(isRecording ? Icons.stop : Icons.play_arrow),
                label: Text(
                    isRecording ? 'Остановить запись' : 'Начать запись'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isRecording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}