// view for displaying the recording page
// uses eeg_plots widget for the chart
// todo: add recording functionality
import 'package:flutter/material.dart';
import 'package:ble_app/widgets/eeg_plots.dart';
import 'dart:math';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  // create the state for the recording page
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  bool isRecording = false;

  @override
  Widget build(BuildContext context) {

    // generate sample data for 1 channel
    final Random random = Random();
    final List<List<FFTDataPoint>> sampleData = [
      List.generate(40, (i) {
        final freq = i * 0.5;
        final amplitude = random.nextDouble() * 10;
        return FFTDataPoint(frequency: freq, amplitude: amplitude);
      })
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Запись ЭЭГ'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                // displaying the recording status indicator
                padding: const EdgeInsets.all(16.0),
                child: Column(
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
                          isRecording ? 'Идет запись' : 'Запись остановлена',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // displaying the power line chart
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
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PowerLineChart(channelData: sampleData),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // button for starting/stopping the recording
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isRecording = !isRecording;
                });
              },
              icon: Icon(isRecording ? Icons.stop : Icons.play_arrow),
              label: Text(isRecording ? 'Остановить запись' : 'Начать запись'),
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
  }
}