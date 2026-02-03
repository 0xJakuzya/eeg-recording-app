/// view for recording and visualizing eeg data
/// displays real-time eeg signal charts, recording controls, and channel selection.
/// allows toggling channel visibility and starting/stopping recordings.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/controllers/recording_controller.dart';
import 'package:ble_app/widgets/eeg_plots.dart';
import 'package:ble_app/widgets/recording_status_card.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => RecordingPageState();
}

class RecordingPageState extends State<RecordingPage> {
  
  final SettingsController settingsController = Get.find<SettingsController>(); // settings controller
  final RecordingController recordingController = Get.find<RecordingController>(); // recording controller

  late Set<int> visibleChannels; // set of visible channel 

  @override
  void initState() {
    super.initState();
    updateVisibleChannels();
  }

  // update visible channels 
  void updateVisibleChannels() {
    final count = settingsController.channelCount.value;
    visibleChannels = Set.from(List.generate(count, (i) => i));
  }

  void toggleChannel(int channel) {
    setState(() => visibleChannels.contains(channel)
        ? visibleChannels.remove(channel)
        : visibleChannels.add(channel));
  }

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
          final time = idx * RecordingConstants.sampleIntervalSeconds;
          final amplitude = ch < sample.channels.length ? sample.channels[ch] : 0.0; 
          return EegDataPoint(time: time, amplitude: amplitude); // return chart data
        }).toList();
      });
    }
    // return demo data if buffer is empty
    return buildDemoData();
  }
  
  // generate demo data for testing
  List<List<EegDataPoint>> buildDemoData() {
    final random = Random(42); // number generator
    final channelCount = settingsController.channelCount.value; // channel count
    return List.generate(channelCount, (channel) {
      return List.generate(RecordingConstants.demoDataPointCount, (i) {
        final time = i * RecordingConstants.sampleIntervalSeconds; 
        final baseFreq = 5.0 + channel * 2; // frequency
        final amplitude = 50 * sin(2 * pi * baseFreq * time) + random.nextDouble() * 20 - 10; // amplitude with noise
        return EegDataPoint(time: time, amplitude: amplitude); // return chart data
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

  void _ensureVisibleChannelsValid(int channelCount) {
    if (visibleChannels.any((ch) => ch >= channelCount)) {
      visibleChannels = visibleChannels.where((ch) => ch < channelCount).toSet();
    }
    if (visibleChannels.isEmpty && channelCount > 0) {
      visibleChannels = Set.from(List.generate(channelCount, (i) => i));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final channelCount = settingsController.channelCount.value;
      final isRecording = recordingController.isRecording.value;
      _ensureVisibleChannelsValid(channelCount);
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
              RecordingStatusCard(isRecording: isRecording),
              const SizedBox(height: 16),
              // channel selection (only for multi-channel)
              if (channelCount > 1)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Каналы (${visibleChannels.length}/$channelCount)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ChannelLegend(
                          channelCount: channelCount,
                          visibleChannels: visibleChannels,
                          onToggle: toggleChannel,
                        ),
                      ],
                    ),
                  ),
                ),
              if (channelCount > 1) const SizedBox(height: 16),
              // eeg signal chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'График сигнала',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: visibleChannels.isEmpty
                            ? const Center(child: Text('Выберите каналы'))
                            : EegLineChart(
                                channelData: chartData,
                                visibleChannels: visibleChannels,
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