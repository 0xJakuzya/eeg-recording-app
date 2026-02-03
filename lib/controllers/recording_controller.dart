// сontroller for recording EEG data
// handles ble data reception, parsing, and csv writing

import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_sample.dart';
import 'package:ble_app/services/csv_stream_writer.dart';
import 'package:ble_app/services/eeg_parser_service.dart';

class RecordingController extends GetxController {

  final BleController bleController = Get.find<BleController>();
  final SettingsController settingsController = Get.find<SettingsController>();
  
  late CsvStreamWriter csvWriter;
  late EegParserService parser;

  RxBool isRecording = false.obs;
  Rx<String?> currentFilePath = Rx<String?>(null);
  RxInt sampleCount = 0.obs;
  Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null);
  Rx<Duration> recordingDuration = Duration.zero.obs;

  RxList<EegSample> realtimeBuffer = <EegSample>[].obs;
  static const int bufferMaxSize = 200; 

  StreamSubscription? dataSubscription;
  Timer? durationTimer;

  @override
  void onInit() {
    super.onInit();
    initServices();
  }

  void initServices() {
    final channels = settingsController.channelCount.value;
    csvWriter = CsvStreamWriter(channelCount: channels);
    parser = EegParserService(channelCount: channels);
  }
  
  // stop recording
  @override
  void onClose() {
    stopRecording();
    super.onClose();
  }

  // start recording data
  Future<void> startRecording() async {

    initServices();
    final characteristic = await findEegCharacteristic();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final channels = settingsController.channelCount.value;
    final filename = 'eeg_${channels}ch_$timestamp.csv';
    
    await csvWriter.startRecording(filename);
    currentFilePath.value = await csvWriter.getFilePath();

    await characteristic?.setNotifyValue(true); 
    dataSubscription = characteristic?.lastValueStream.listen(onDataReceived);

    isRecording.value = true;
    recordingStartTime.value = DateTime.now();
    sampleCount.value = 0;
    realtimeBuffer.clear();

    startDurationTimer();
    print('Recording started: $filename');
  }

  // stop recording
  Future<void> stopRecording() async {
    await dataSubscription?.cancel();
    dataSubscription = null;

    durationTimer?.cancel();
    durationTimer = null;

    await csvWriter.stopRecording(); 

    final samples = sampleCount.value;
    final path = currentFilePath.value;

    isRecording.value = false;
    
    print('Recording stopped. Total samples: $samples');
    print('File saved: $path');


    await Future.delayed(const Duration(seconds: 3));
    
    currentFilePath.value = null;
    recordingStartTime.value = null;
    recordingDuration.value = Duration.zero;
  }

  // parse bytes and write to csv
  void onDataReceived(List<int> bytes) {
    final sample = parser.parseBytes(bytes);
    csvWriter.writeSample(sample);
    sampleCount.value++;
    realtimeBuffer.add(sample);
    if (realtimeBuffer.length > bufferMaxSize) {
      realtimeBuffer.removeAt(0);
    }
  }
  
  // find the eeg characteristic
  Future<BluetoothCharacteristic?> findEegCharacteristic() async {
    final services = bleController.services;
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          print('Found notify characteristic: ${characteristic.uuid}');
          return characteristic;
        }
      }
    }
    return null;
  }

  // start duration timer
  void startDurationTimer() {
    durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (recordingStartTime.value != null) {
        recordingDuration.value = DateTime.now().difference(recordingStartTime.value!);
      }
    });
  }

  // get formatted duration
  String get formattedDuration {
    final duration = recordingDuration.value;
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // get sample rate
  double get sampleRate {
    if (recordingStartTime.value == null || sampleCount.value == 0) {
      return 0.0;
    }
    final elapsed = DateTime.now().difference(recordingStartTime.value!);
    if (elapsed.inSeconds == 0) return 0.0;
    return sampleCount.value / elapsed.inSeconds;
  }

  List<List<double>> getRealtimeChartData() {
    final channelCount = settingsController.channelCount.value;
    final result = List.generate(channelCount, (_) => <double>[]);
    
    for (final sample in realtimeBuffer) {
      for (int ch = 0; ch < channelCount && ch < sample.channels.length; ch++) {
        result[ch].add(sample.channels[ch]);
      }
    }
    return result;
  }
}
