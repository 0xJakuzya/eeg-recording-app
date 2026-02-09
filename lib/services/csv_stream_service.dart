import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/eeg_sample.dart';

// service for writing eeg samples to csv files
// uses a buffer to store samples and periodically flush them to the file.
// manages file creation, header generation, and stream writing operations.
class CsvStreamWriter {

  File? file; 
  IOSink? sink; 
  String? currentFilePath;
  int channelCount;
  int sampleCounter = 0;

  final List<String> buffer = []; 

  CsvStreamWriter({this.channelCount = 1});

  // generate header
  String generateHeader() {
    final channelNames =
        List.generate(channelCount, (i) => 'channel${i + 1}').join(',');
    return 'time,$channelNames';
  }

  // start recording
  Future<void> startRecording(String filename, {String? baseDirectory}) async {
    sampleCounter = 0;
    final String dirPath;
    if (baseDirectory != null && baseDirectory.isNotEmpty) {
      dirPath = baseDirectory;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      dirPath = directory.path;
    }
    currentFilePath = '$dirPath${dirPath.endsWith(Platform.pathSeparator) ? '' : Platform.pathSeparator}$filename';
    file = File(currentFilePath!);
    sink = file!.openWrite(mode: FileMode.writeOnly);
    sink!.writeln(generateHeader());
  }

  // write a sample to the buffer
  void writeSample(EegSample sample) {
    sampleCounter++;
    buffer.add('$sampleCounter,${sample.channels.join(',')}'); 
    if (buffer.length >= RecordingConstants.csvBufferSize) { 
      // flush buffer
      flushBuffer();
    }
  }

  // write raw data to the buffer
  void writeRawData(DateTime timestamp, List<double> channels) {
    final sample = EegSample(timestamp: timestamp, channels: channels);
    writeSample(sample);
  }

  // flush the buffer to disk
  void flushBuffer() {
    if (buffer.isEmpty || sink == null) return;
    sink!.writeAll(buffer, '\n');
    buffer.clear();
  }

  // stop recording and close file
  Future<void> stopRecording() async {
    flushBuffer(); 
    await sink?.flush();
    await sink?.close();  
    sink = null;
    file = null;
  }

  /// current recording file path 
  String? get filePath => currentFilePath;

  // get the file size in bytes
  Future<int> getFileSize() async {
    if (file == null || !await file!.exists()) return 0;
    return await file!.length();
  }

  // check if recording is active
  bool get isRecording => sink != null;
}
