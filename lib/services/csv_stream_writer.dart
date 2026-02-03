// service for writing eeg samples to a csv file
// uses a buffer to store the samples and flush them to the file

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ble_app/models/eeg_sample.dart';

class CsvStreamWriter {

  File? file; 
  IOSink? sink; 
  String? currentFilePath;
  int channelCount;

  final List<String> buffer = []; 
  static const int bufferSize = 100; 

  CsvStreamWriter({this.channelCount = 1});

  // generate csv header based on channel count
  String generateHeader() {
    final channelNames = List.generate(channelCount, (i) => 'ch${i + 1}').join(',');
    return 'timestamp,$channelNames';
  }

  // start recording
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
    buffer.add(sample.toCsvLine()); 
    if (buffer.length >= bufferSize) { 
      flushBuffer();
    }
  }

  // write raw data to the buffer
  void writeRawData(DateTime timestamp, List<double> channels) {
    final sample = EegSample(timestamp: timestamp, channels: channels);
    writeSample(sample);
  }

  // flush the buffer
  void flushBuffer() {
    if (buffer.isEmpty || sink == null) return;
    sink!.writeAll(buffer, '\n');
    sink!.writeln(); 
    buffer.clear();
  }

  // stop recording
  Future<void> stopRecording() async {
    flushBuffer();
    await sink?.flush();
    await sink?.close();  
    print('CSV recording stopped. File: $currentFilePath');
    sink = null;
    file = null;
  }

  // get the file path
  Future<String?> getFilePath() async {
    return currentFilePath;
  }

  // get the file size
  Future<int> getFileSize() async {
    if (file == null || !await file!.exists()) return 0;
    return await file!.length();
  }

  // check if recording is active
  bool get isRecording => sink != null;
}
