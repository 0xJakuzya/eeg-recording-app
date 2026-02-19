import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/core/common/eeg_sample.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

<<<<<<< HEAD:lib/services/csv_stream_service.dart
/// service for writing eeg samples to csv (txt) files
/// return rows: `<index> <value>`

=======
/// Service for writing EEG samples to CSV (txt) files.
/// Format: sample{delim}ch1{delim}ch2...
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
class CsvStreamWriter {
  File? file;
  IOSink? sink;
  String? currentFilePath;
  String? baseDirectory;
  String? baseFilename;
<<<<<<< HEAD:lib/services/csv_stream_service.dart

  int channelCount;

  int sampleCounter = 0;
  int lastWrittenNumber = 0;

  final List<String> buffer = [];
  final Set<int> bufferSampleNumbers = <int>{};
  final Map<int, List<double>> bufferSampleValues = <int, List<double>>{};

  // rotation settings
=======
  int channelCount;
  int sampleCounter = 0;
  bool outputVolts = false;

  final List<String> buffer = [];
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
  final Duration rotationInterval;
  DateTime? currentFileStartedAt;
  int partIndex = 1;

  CsvStreamWriter({
    this.channelCount = 8,
    required this.rotationInterval,
    this.outputVolts = false,
  });

<<<<<<< HEAD:lib/services/csv_stream_service.dart
  // start recording
  Future<void> startRecording(
    String filename, {
    String? baseDirectory,
  }) async {
=======
  Future<void> startRecording(String filename, {String? baseDirectory}) async {
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
    sampleCounter = 0;
    lastWrittenNumber = 0;
    partIndex = 1;
    baseFilename = filename;
    this.baseDirectory = baseDirectory;

    bufferSampleNumbers.clear();
    bufferSampleValues.clear();

    await openNewFile();
  }

  Future<void> openNewFile() async {
    final String dirPath;
    final baseDir = baseDirectory;
    if (baseDir != null && baseDir.isNotEmpty) {
      dirPath = baseDir;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      dirPath = directory.path;
    }

    currentFileStartedAt = DateTime.now();
    final baseTime = rotationInterval > Duration.zero
        ? currentFileStartedAt!.add(rotationInterval)
        : currentFileStartedAt!;

    final fname = buildRotatedFilename(
      baseFilename ??
          '${RecordingConstants.defaultRecordingBaseName}${RecordingConstants.recordingFileExtension}',
      baseTime,
      partIndex,
    );

    currentFilePath =
        '$dirPath${dirPath.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator}$fname';
    file = File(currentFilePath!);
    sink = file!.openWrite(mode: FileMode.writeOnly);
  }

  String buildRotatedFilename(
<<<<<<< HEAD:lib/services/csv_stream_service.dart
    String originalName,
    DateTime startedAt,
    int partIndex,
  ) {
=======
      String originalName, DateTime startedAt, int partIndex) {
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
    final dotIndex = originalName.lastIndexOf('.');
    String ext;
    String base;
    if (dotIndex != -1) {
      base = originalName.substring(0, dotIndex);
      ext = originalName.substring(dotIndex);
    } else {
      base = originalName;
      ext = RecordingConstants.recordingFileExtension;
    }

    final datePart = startedAt.format('dd.MM.yyyy');
    final timePart = startedAt.format('HH-mm');
<<<<<<< HEAD:lib/services/csv_stream_service.dart

    return '${base}_${datePart}_${timePart}_part$partIndex$ext';
  }

  // write a sample to the buffer (supports 1..N channels)
  void writeSample(EegSample sample) {
    sampleCounter++;
    final values = sample.channels.isNotEmpty
        ? sample.channels
        : List<double>.filled(channelCount, 0.0);

    if (bufferSampleNumbers.contains(sampleCounter)) {
      final existing = bufferSampleValues[sampleCounter];
      if (existing != null &&
          existing.length == values.length &&
          _listEquals(existing, values)) {
        return;
      }
    }

    for (final v in values) {
      if (v.isNaN || v.isInfinite) return;
    }

    final valueStrs = values.map((v) => v.toString()).toList();
    if (valueStrs.any((s) => s.contains(' ') || s.split(' ').length > 1)) {
      return;
    }
    final line = '$sampleCounter ${valueStrs.join(' ')}';
    buffer.add(line);
    bufferSampleNumbers.add(sampleCounter);
    bufferSampleValues[sampleCounter] = List.from(values);
    checkRotation();
    if (buffer.length >= RecordingConstants.csvBufferSize) {
      flushBuffer();
    }
  }

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // write raw data to the buffer 
=======
    return '${base}_${datePart}_$timePart$ext';
  }

  void writeSample(EegSample sample) {
    sampleCounter++;
    final delim = RecordingConstants.csvDelimiter;
    if (outputVolts) {
      final chs = sample.channels
          .take(channelCount)
          .map((v) => v.toStringAsFixed(6))
          .join(delim);
      buffer.add('$sampleCounter$delim$chs');
    } else {
      final value = sample.channels.isNotEmpty ? sample.channels[0] : 0.0;
      buffer.add('$sampleCounter$delim$value');
    }
    checkRotation();
    if (buffer.length >= RecordingConstants.csvBufferSize) flushBuffer();
  }

>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
  void writeRawData(DateTime timestamp, List<double> channels) {
    final sample = EegSample(timestamp: timestamp, channels: channels);
    writeSample(sample);
  }

  void flushBuffer() {
    if (buffer.isEmpty || sink == null) return;
<<<<<<< HEAD:lib/services/csv_stream_service.dart

    final validLines = <String>[];
    final seenNumbers = <int>{};
    final seenNumberValues = <int, List<double>>{};

    for (final line in buffer) {
      final parts = line.split(' ');
      if (parts.length < 2) continue;

      final numberStr = parts[0];
      final number = int.tryParse(numberStr);
      if (number == null) continue;
      if (number <= lastWrittenNumber) continue;

      final values = <double>[];
      for (var i = 1; i < parts.length; i++) {
        final v = double.tryParse(parts[i]);
        if (v == null) break;
        values.add(v);
      }
      if (values.isEmpty) continue;

      if (seenNumbers.contains(number)) {
        final existing = seenNumberValues[number];
        if (existing != null &&
            existing.length == values.length &&
            _listEquals(existing, values)) {
          continue;
        }
      }

      validLines.add(line);
      seenNumbers.add(number);
      seenNumberValues[number] = values;
    }

    if (validLines.isNotEmpty) {
      sink!.write(validLines.join('\n') + '\n');
      if (seenNumbers.isNotEmpty) {
        lastWrittenNumber =
            seenNumbers.reduce((a, b) => a > b ? a : b);
      }
    }

=======
    sink!.write(buffer.join('\n'));
    sink!.writeln();
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
    buffer.clear();
    bufferSampleNumbers.clear();
    bufferSampleValues.clear();
  }

<<<<<<< HEAD:lib/services/csv_stream_service.dart
  // stop recording and close file
  Future<void> stopRecording() async {
=======
  Future<void> stopRecording({double? durationSeconds}) async {
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
    flushBuffer();
    await sink?.flush();
    await sink?.close();
    sink = null;
    final path = currentFilePath;
    file = null;
    if (path != null && durationSeconds != null && durationSeconds > 0) {
      final effHz = sampleCounter / durationSeconds;
      final metaLine =
          '# duration_seconds=${durationSeconds.toStringAsFixed(1)};sample_count=$sampleCounter;effective_hz=${effHz.toStringAsFixed(0)}';
      final f = File(path);
      if (await f.exists()) {
        final content = await f.readAsString();
        await f.writeAsString('$metaLine\n$content');
      }
    }
  }

  void checkRotation() {
    if (sink == null || currentFileStartedAt == null) return;
    if (rotationInterval <= Duration.zero) return;
    final now = DateTime.now();
    if (now.difference(currentFileStartedAt!) >= rotationInterval) {
      rotateFile();
    }
  }

  Future<void> rotateFile() async {
    flushBuffer();
    await sink?.flush();
    await sink?.close();
    sink = null;
    file = null;
    partIndex++;
    lastWrittenNumber = 0;
    sampleCounter = 0;
    await openNewFile();
  }

<<<<<<< HEAD:lib/services/csv_stream_service.dart
  /// current recording file path
=======
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/recording/csv_stream_service.dart
  String? get filePath => currentFilePath;

  Future<int> getFileSize() async {
    if (file == null || !await file!.exists()) return 0;
    return await file!.length();
  }

  bool get isRecording => sink != null;
}
