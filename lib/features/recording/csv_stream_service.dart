import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/core/common/eeg_sample.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

class CsvStreamWriter {
  File? file;
  IOSink? sink;
  String? currentFilePath;
  String? baseDirectory;
  String? baseFilename;
  int sampleCounter = 0;
  String fileExtension;
  // polysomnography format: .txt, metadata header + one volts value per row
  final bool isPolysomnographyFormat;

  final List<String> buffer = [];
  final Duration rotationInterval;
  DateTime? currentFileStartedAt;
  int partIndex = 1;

  CsvStreamWriter({
    required this.rotationInterval,
    this.fileExtension = '.txt',
    this.isPolysomnographyFormat = false,
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

  void writeSample(EegSample sample, int absoluteTimestampMs) {
    sampleCounter++;
    if (RecordingConstants.eegDataFlowDebug && (sampleCounter <= 3 || sampleCounter % 100 == 0)) {
      print('[EEG] 4.CSV: wrote sample #$sampleCounter value=${sample.volts.toStringAsFixed(6)}');
    }
    final line = isPolysomnographyFormat
        ? sample.volts.toStringAsFixed(6)
        : sample.toCsvLine(absoluteTimestampMs);
    buffer.add(line);
    checkRotation();
    if (buffer.length >= RecordingConstants.csvBufferSize) flushBuffer();
  }

  void flushBuffer() {
    if (buffer.isEmpty || sink == null) return;
    sink!.write(buffer.join('\n'));
    sink!.writeln();
    buffer.clear();
  }

  Future<void> stopRecording() async {
    flushBuffer();
    await sink?.flush();
    await sink?.close();
    sink = null;
    file = null;
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
    sampleCounter = 0;
    await openNewFile();
  }

  String? get filePath => currentFilePath;

  Future<int> getFileSize() async {
    if (file == null || !await file!.exists()) return 0;
    return await file!.length();
  }

  bool get isRecording => sink != null;
}
