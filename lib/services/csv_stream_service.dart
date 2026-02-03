/// service for writing eeg samples to csv files
/// uses a buffer to store samples and periodically flush them to the file.
/// manages file creation, header generation, and stream writing operations.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/eeg_sample.dart';

class CsvStreamWriter {

  File? file; 
  IOSink? sink; 
  String? currentFilePath;
  int channelCount;

  final List<String> buffer = []; // buffer to store csv lines before flushing to disk

  CsvStreamWriter({this.channelCount = 1});

  String generateHeader() {
    // generate channel names as ch1, ch2, ch3, etc.
    final channelNames = List.generate(channelCount, (i) => 'ch${i + 1}').join(',');
    return 'timestamp,$channelNames';
  }

  // start recording to a new csv file
  Future<void> startRecording(String filename) async {
    final directory = await getApplicationDocumentsDirectory(); 
    currentFilePath = '${directory.path}/$filename';
    file = File(currentFilePath!); 
    sink = file!.openWrite(mode: FileMode.writeOnly); 
    sink!.writeln(generateHeader()); 
    print('CSV recording started: $currentFilePath');
  }

  // write a sample to the buffer
  void writeSample(EegSample sample) {
    buffer.add(sample.toCsvLine()); // convert sample to csv line and add to buffer
    if (buffer.length >= RecordingConstants.csvBufferSize) { 
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
    sink!.writeAll(buffer, '\n'); // write all buffered lines to file
    sink!.writeln(); // write newline to file
    buffer.clear();
  }

  // stop recording and close file
  Future<void> stopRecording() async {
    flushBuffer(); 
    await sink?.flush();
    await sink?.close();  
    print('CSV recording stopped. File: $currentFilePath');
    sink = null;
    file = null;
  }

  /// current recording file path (null when not recording)
  String? get filePath => currentFilePath;

  // get the file size in bytes
  Future<int> getFileSize() async {
    if (file == null || !await file!.exists()) return 0;
    return await file!.length();
  }

  // check if recording is active
  bool get isRecording => sink != null;
}
