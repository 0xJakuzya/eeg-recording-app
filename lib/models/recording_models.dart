import 'dart:io';
import 'package:ble_app/utils/extension.dart';

/// Metadata from CSV footer: # duration_seconds=X;sample_count=Y;effective_hz=Z
class CsvRecordingMetadata {
  final double durationSeconds;
  final int sampleCount;
  final double effectiveHz;

  const CsvRecordingMetadata({
    required this.durationSeconds,
    required this.sampleCount,
    required this.effectiveHz,
  });

  static Future<CsvRecordingMetadata?> fromFile(File file) async {
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final lines = content.split('\n');
      for (var i = lines.length - 1; i >= 0; i--) {
        final line = lines[i].trim();
        if (line.startsWith('# duration_seconds=')) {
          double? dur;
          int? samples;
          double? hz;
          for (final part in line.substring(1).split(';')) {
            final kv = part.split('=');
            if (kv.length == 2) {
              final k = kv[0].trim();
              final v = kv[1].trim();
              if (k == 'duration_seconds') dur = double.tryParse(v);
              if (k == 'sample_count') samples = int.tryParse(v);
              if (k == 'effective_hz') hz = double.tryParse(v);
            }
          }
          if (dur != null && dur > 0 && samples != null && samples > 0) {
            return CsvRecordingMetadata(
              durationSeconds: dur,
              sampleCount: samples,
              effectiveHz: hz ?? (samples / dur),
            );
          }
          return null;
        }
      }
    } catch (ignored) {}
    return null;
  }
}

class RecordingFileInfo {

  final File file;
  final String name;
  final DateTime modified;
  final int sizeBytes;

  RecordingFileInfo({
    required this.file,
    required this.name,
    required this.modified,
    required this.sizeBytes,
  });
  String get formattedModified => modified.toLocal().format('dd.MM.yyyy HH:mm');
  String get formattedSize => sizeBytes.formatBytes();
}

class RecordingDirectoryContent {

  final Directory directory;
  final List<Directory> subdirectories;
  final List<RecordingFileInfo> files;

  RecordingDirectoryContent({
    required this.directory,
    required this.subdirectories,
    required this.files,
  });
}


