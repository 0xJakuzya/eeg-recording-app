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
import 'package:ble_app/core/ble_constants.dart';
import 'package:ble_app/services/csv_stream_service.dart';
import 'package:ble_app/services/eeg_parser_service.dart';

class RecordingController extends GetxController {

  final BleController bleController = Get.find<BleController>(); //ble controller
  final SettingsController settingsController = Get.find<SettingsController>(); //settings controller
  
  late CsvStreamWriter csvWriter; 
  late EegParserService parser; 

  RxBool isRecording = false.obs; 
  Rx<String?> currentFilePath = Rx<String?>(null); 
  RxInt sampleCount = 0.obs; 
  Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null); 
  Rx<Duration> recordingDuration = Duration.zero.obs; 

  RxList<EegSample> realtimeBuffer = <EegSample>[].obs; 

  StreamSubscription? dataSubscription; 
  Timer? durationTimer; 
  int _debugPrintCount = 0; // temporary debug counter for channel data

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
    _debugPrintCount = 0; // reset debug counter for new session

    // locate EEG data and config characteristics by UUID
    BluetoothCharacteristic? dataChar;
    BluetoothCharacteristic? configChar;
    for (final service in bleController.services) {
      final serviceUuid = service.uuid.str;
      if (serviceUuid == BleConstants.eegServiceUuid) {
        for (final c in service.characteristics) {
          if (c.uuid.str == BleConstants.eegDataCharUuid) {
            dataChar = c;
          }
        }
      }
      if (serviceUuid == BleConstants.eegConfigServiceUuid) {
        for (final c in service.characteristics) {
          if (c.uuid.str == BleConstants.eegConfigCharUuid) {
            configChar = c;
          }
        }
      }
    }

    // ensure we have a data characteristic
    final BluetoothCharacteristic? dataCharacteristic = dataChar;

    // send configuration command if config characteristic is available
    if (configChar != null) {
      final freq = BleConstants.defaultSampleRateHz;
      final cmd = <int>[
        0x81,
        freq % 256,
        freq ~/ 256,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
      ];
      // write with response 
      await configChar.write(cmd, withoutResponse: false);
    }

    // generate filename
    final timestamp = DateTime.now().millisecondsSinceEpoch; 
    final channels = settingsController.channelCount.value; 
    final filename = 'eeg_${channels}ch_$timestamp.csv'; 

    await csvWriter.startRecording(filename);
    currentFilePath.value = csvWriter.filePath; 

    // enable notifications on EEG data characteristic
    await dataCharacteristic?.setNotifyValue(true);

    // listen to data stream
    dataSubscription = dataCharacteristic?.lastValueStream.listen(onDataReceived); 

    isRecording.value = true; 
    recordingStartTime.value = DateTime.now(); 
    sampleCount.value = 0; 
    realtimeBuffer.clear(); 

    startDurationTimer(); 
    print('Recording started: $filename');
  }

  // stop recording
  Future<void> stopRecording() async {
    
    // cancel data subscription
    await dataSubscription?.cancel(); 
    dataSubscription = null;

    // stop duration timer
    durationTimer?.cancel(); 
    durationTimer = null;

    // stop write to csv
    await csvWriter.stopRecording();

    //
    final samples = sampleCount.value; 
    final path = currentFilePath.value; 

    // update recording state
    isRecording.value = false; 
    
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

    // debug: print first few packets to verify channel mapping
    if (_debugPrintCount < 5) {
      _debugPrintCount++;
      final hex = bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      print('EEG DEBUG: raw bytes len=${bytes.length}, hex=[$hex]');
      print('EEG DEBUG: channels (${sample.channels.length}) = ${sample.channels}');
    }

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
