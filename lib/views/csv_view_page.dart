import 'package:flutter/material.dart';
import 'package:ble_app/controllers/files_controller.dart';

class CsvViewPage extends StatelessWidget {
  const CsvViewPage({super.key, required this.info});

  final RecordingFileInfo info;

  Future<String> loadContent() async {
    final file = info.file;
    if (!await file.exists()) {
      return 'Файл не найден';
    }
    return await file.readAsString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(info.name),
      ),
      body: FutureBuilder<String>(
        future: loadContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка чтения файла: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          final text = snapshot.data ?? '';
          if (text.isEmpty) {
            return const Center(
              child: Text('Файл пустой'),
            );
          }
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectableText(
                    text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

