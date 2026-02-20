import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/core/common/eeg_sample.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

/// Service for writing EEG samples to CSV (txt) files.
/// Format: sample{delim}ch1{delim}ch2...
class CsvStreamWriter {
  File? file;
  IOSink? sink;
  String? currentFilePath;
  String? baseDirectory;
  String? baseFilename;
  int channelCount;
  int sampleCounter = 0;
  bool outputVolts = false;
  String fileExtension;

  final List<String> buffer = [];
  final Duration rotationInterval;
  DateTime? currentFileStartedAt;
  int partIndex = 1;

  CsvStreamWriter({
    this.channelCount = 1,
    required this.rotationInterval,
    this.outputVolts = false,
    this.fileExtension = '.txt',
  });

  Future<void> startRecording(String filename, {String? baseDirectory}) async {
    sampleCounter = 0;
    partIndex = 1;
    baseFilename = filename;
    this.baseDirectory = baseDirectory;
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
          '${RecordingConstants.defaultRecordingBaseName}$fileExtension',
      baseTime,
      partIndex,
    );

    currentFilePath =
        '$dirPath${dirPath.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator}$fname';
    file = File(currentFilePath!);
    sink = file!.openWrite(mode: FileMode.writeOnly);
  }

  String buildRotatedFilename(
      String originalName, DateTime startedAt, int partIndex) {
    final dotIndex = originalName.lastIndexOf('.');
    String ext;
    String base;
    if (dotIndex != -1) {
      base = originalName.substring(0, dotIndex);
      ext = originalName.substring(dotIndex);
    } else {
      base = originalName;
      ext = fileExtension;
    }
    final datePart = startedAt.format('dd.MM.yyyy');
    final timePart = startedAt.format('HH-mm');
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

  void writeRawData(DateTime timestamp, List<double> channels) {
    final sample = EegSample(timestamp: timestamp, channels: channels);
    writeSample(sample);
  }

  void flushBuffer() {
    if (buffer.isEmpty || sink == null) return;
    sink!.write(buffer.join('\n'));
    sink!.writeln();
    buffer.clear();
  }

  Future<void> stopRecording({double? durationSeconds}) async {
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
    await openNewFile();
  }

  String? get filePath => currentFilePath;

  Future<int> getFileSize() async {
    if (file == null || !await file!.exists()) return 0;
    return await file!.length();
  }

  bool get isRecording => sink != null;
}
