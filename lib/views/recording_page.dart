import 'package:flutter/material.dart';

class RecordingPage extends StatelessWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Запись'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fiber_manual_record, size: 100, color: Colors.red),
            const SizedBox(height: 20),
            const Text('Запись ЭЭГ данных', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: start recording
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Начать запись'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(200, 50),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: stop recording
              },
              icon: const Icon(Icons.stop),
              label: const Text('Остановить запись'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}