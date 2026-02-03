/// controller for recording eeg data
/// handles ble data reception, parsing, and csv writing.
/// manages recording state, sample buffering, and real-time data visualization.

import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_sample.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/services/csv_stream_service.dart';
import 'package:ble_app/services/eeg_parser_service.dart';

class RecordingController extends GetxController {

  final BleController bleController = Get.find<BleController>(); //ble controller
  final SettingsController settingsController = Get.find<SettingsController>(); //settings controller
  
  late CsvStreamWriter csvWriter; //writing to csv
  late EegParserService parser; //parsing bytes

  RxBool isRecording = false.obs; //recording state
  Rx<String?> currentFilePath = Rx<String?>(null); //current file path
  RxInt sampleCount = 0.obs; //sample count
  Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null); //recording start time
  Rx<Duration> recordingDuration = Duration.zero.obs; //recording duration

  RxList<EegSample> realtimeBuffer = <EegSample>[].obs; //realtime buffer

  StreamSubscription? dataSubscription; //subscription for data stream
  Timer? durationTimer; //timer for recording duration

  @override
  void onInit() {
    super.onInit();
    initServices();
  }

  // initialize services
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
    
    // find the eeg characteristic
    final characteristic = await findEegCharacteristic(); 

    // generate filename
    final timestamp = DateTime.now().millisecondsSinceEpoch; 
    final channels = settingsController.channelCount.value; 
    final filename = 'eeg_${channels}ch_$timestamp.csv'; 

    await csvWriter.startRecording(filename);
    currentFilePath.value = csvWriter.filePath; 

    await characteristic?.setNotifyValue(true); // set notify value 
    dataSubscription = characteristic?.lastValueStream.listen(onDataReceived); // listen to data stream 

    isRecording.value = true; // set recording state 
    recordingStartTime.value = DateTime.now(); // set recording start time
    sampleCount.value = 0; // set sample count 
    realtimeBuffer.clear(); // clear realtime buffer

    startDurationTimer(); // start duration timer
    print('Recording started: $filename');
  }

  // stop recording
  Future<void> stopRecording() async {
    
    await dataSubscription?.cancel(); // cancel data subscription
    dataSubscription = null;

    durationTimer?.cancel(); // stop duration timer
    durationTimer = null;

    await csvWriter.stopRecording(); // stop write to csv

    final samples = sampleCount.value; // get sample count
    final path = currentFilePath.value; // get current file path

    isRecording.value = false; // update recording state
    
    print('Recording stopped. Total samples: $samples');
    print('File saved: $path');

    // wait for 3 seconds
    await Future.delayed(RecordingConstants.postStopDelay); 

    // reset values    
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
    if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {
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
    durationTimer = Timer.periodic(RecordingConstants.durationTimerInterval, (timer) {
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
    // return formatted duration as HH:MM:SS
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
}
