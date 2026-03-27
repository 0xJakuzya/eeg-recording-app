import 'package:flutter/material.dart';
import 'package:ble_app/core/common/recording_models.dart';

// lazy line-by-line file viewer; reads file once, renders via ListView.builder
class CsvViewPage extends StatelessWidget {
  const CsvViewPage({super.key, required this.info});

  final RecordingFileInfo info;

  Future<List<String>> loadLines() async {
    final file = info.file;
    if (!await file.exists()) return ['Файл не найден'];
    return await file.readAsLines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(info.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                info.formattedSize,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: loadLines(),
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
          final lines = snapshot.data ?? [];
          if (lines.isEmpty) {
            return const Center(child: Text('Файл пустой'));
          }
          return Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 1,
                    ),
                    child: Text(
                      lines[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
