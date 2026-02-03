import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/controllers/recording_controller.dart';
import 'package:ble_app/widgets/eeg_plots.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => RecordingPageState();
}

class RecordingPageState extends State<RecordingPage> {
  final SettingsController settingsController = Get.find<SettingsController>();
  final RecordingController recordingController = Get.find<RecordingController>();

  late Set<int> visibleChannels;

  @override
  void initState() {
    super.initState();
    updateVisibleChannels();
  }

  void updateVisibleChannels() {
    final count = settingsController.channelCount.value;
    visibleChannels = Set.from(List.generate(count, (i) => i));
  }

  void toggleChannel(int channel) {
    setState(() {
      if (visibleChannels.contains(channel)) {
        visibleChannels.remove(channel);
      } else {
        visibleChannels.add(channel);
      }
    });
  }
  List<List<EegDataPoint>> buildChartData() {
    final channelCount = settingsController.channelCount.value;
    final buffer = recordingController.realtimeBuffer;
    if (buffer.isNotEmpty) {
      return List.generate(channelCount, (ch) {
        return buffer.asMap().entries.map((entry) {
          final idx = entry.key;
          final sample = entry.value;
          final time = idx * 0.05; 
          final amplitude = ch < sample.channels.length ? sample.channels[ch] : 0.0;
          return EegDataPoint(time: time, amplitude: amplitude);
        }).toList();
      });
    }

    return buildDemoData();
  }
  List<List<EegDataPoint>> buildDemoData() {
    final random = Random(42);
    final channelCount = settingsController.channelCount.value;
    return List.generate(channelCount, (channel) {
      return List.generate(200, (i) {
        final time = i * 0.05; 
        final baseFreq = 5.0 + channel * 2;
        final amplitude = 50 * sin(2 * pi * baseFreq * time) +
            random.nextDouble() * 20 - 10;
        return EegDataPoint(time: time, amplitude: amplitude);
      });
    });
  }

  Future<void> toggleRecording() async {
    if (recordingController.isRecording.value) {
      await recordingController.stopRecording();
    } else {
      await recordingController.startRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final channelCount = settingsController.channelCount.value;
      final isRecording = recordingController.isRecording.value;

      if (visibleChannels.any((ch) => ch >= channelCount)) {
        visibleChannels =
            visibleChannels.where((ch) => ch < channelCount).toSet();
      }
      if (visibleChannels.isEmpty && channelCount > 0) {
        visibleChannels = Set.from(List.generate(channelCount, (i) => i));
      }

      final chartData = buildChartData();

      return Scaffold(
        appBar: AppBar(
          title: Text('Запись ЭЭГ ($channelCount кан.)'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isRecording
                            ? Icons.fiber_manual_record
                            : Icons.stop_circle,
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
              ),
              const SizedBox(height: 16),
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
}