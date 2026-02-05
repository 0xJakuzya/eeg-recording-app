import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_sample.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/core/ble_constants.dart';
import 'package:ble_app/services/csv_stream_service.dart';
import 'package:ble_app/services/eeg_parser_service.dart';
import 'package:ble_app/utils/signal_filters.dart';
import 'package:ble_app/widgets/eeg_foreground_handler.dart';

// controller for recording eeg data
// handles ble data reception, parsing, and csv writing.
// manages recording state, sample buffering, and real-time data visualization.
class RecordingController extends GetxController {

  final BleController bleController = Get.find<BleController>(); //ble controller
  final SettingsController settingsController = Get.find<SettingsController>(); //settings controller
  
  late CsvStreamWriter csvWriter; // csv writer
  late EegParserService parser; // eeg parser service
  late List<BandpassFilter1D> channelFilters; // channel filters

  RxBool isRecording = false.obs; // is recording
  Rx<String?> currentFilePath = Rx<String?>(null); // current file path
  RxInt sampleCount = 0.obs; 
  Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null); 
  Rx<Duration> recordingDuration = Duration.zero.obs; // recording duration

  RxList<EegSample> realtimeBuffer = <EegSample>[].obs; // real-time buffer

  StreamSubscription? dataSubscription; // data subscription
  Timer? durationTimer; // duration timer
  bool foregroundTaskInited = false; // foreground task initialized

  @override
  void onInit() {
    super.onInit();
    initServices();
  }

  // initialize services
  void initServices() {
    final channels = settingsController.channelCount.value;
    // initialize csv writer
    csvWriter = CsvStreamWriter(channelCount: channels);
    // initialize eeg parser service
    parser = EegParserService(channelCount: channels);
    // generate bandpass filters for each channel
    channelFilters = List.generate(
      channels,
      (_) => BandpassFilter1D(
        fs: BleConstants.defaultSampleRateHz.toDouble(),
        lowCut: RecordingConstants.defaultBandpassLowHz,
        highCut: RecordingConstants.defaultBandpassHighHz,
      ),
    );
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
    // locate EEG data and config characteristics by UUID
    BluetoothCharacteristic? dataChar;
    BluetoothCharacteristic? configChar;
    // find data and config characteristics in services
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

    // get data characteristic
    final BluetoothCharacteristic? dataCharacteristic = dataChar;

    // send configuration command to set sample rate to default value
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

    // start foreground service when app is backgrounded
    if (Platform.isAndroid || Platform.isIOS) {
      await ensureForegroundTaskInited();
      await FlutterForegroundTask.startService(
        notificationTitle: 'Запись ЭЭГ',
        notificationText: 'Идёт запись. Нажмите, чтобы открыть приложение.',
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        callback: startEegForegroundCallback,
      );
    }

    // generate filename and start CSV in selected or default directory
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final channels = settingsController.channelCount.value;
    final filename = 'eeg_${channels}ch_$timestamp.csv';
    final baseDir = settingsController.recordingDirectory.value;

    await csvWriter.startRecording(filename, baseDirectory: baseDir);
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
  }

  // stop recording
  Future<void> stopRecording() async {
    // cancel data subscription
    await dataSubscription?.cancel(); 
    dataSubscription = null;
    // stop duration timer
    durationTimer?.cancel(); 
    durationTimer = null;
    // stop write to csv an flush buffer
    await csvWriter.stopRecording();
    // stop foreground service
    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterForegroundTask.stopService();
    }
    // update recording state 
    isRecording.value = false;
    // wait for the recording to stop completely
    await Future.delayed(RecordingConstants.postStopDelay);
    recordingStartTime.value = null;
    recordingDuration.value = Duration.zero;
  }
  // foreground task is initialized
  Future<void> ensureForegroundTaskInited() async {
    if (foregroundTaskInited) return;
    final notifPerm = await FlutterForegroundTask.checkNotificationPermission();
    if (notifPerm != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'eeg_recording',
        channelName: 'Запись ЭЭГ',
        channelDescription: 'Уведомление во время записи ЭЭГ',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    foregroundTaskInited = true;
  }

  // parse bytes and write to csv
  void onDataReceived(List<int> bytes) { 
    // ignore empty/invalid packets that don't contain at least 1 channel
    if (bytes.length <= 1) {
      return;
    }

    final rawSample = parser.parseBytes(bytes); 

    // write raw data to CSV
    csvWriter.writeSample(rawSample); 
    sampleCount.value++;

    // apply bandpass filter per channel for visualization
    final filteredChannels = <double>[];
    final channelCount = settingsController.channelCount.value;
    for (int ch = 0; ch < channelCount; ch++) {
      final value =
          ch < rawSample.channels.length ? rawSample.channels[ch] : 0.0;
      final filtered = channelFilters[ch].process(value);
      filteredChannels.add(filtered);
    }

    final filteredSample = EegSample(
      timestamp: rawSample.timestamp,
      channels: filteredChannels,
    );

    realtimeBuffer.add(filteredSample);
    if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {
      realtimeBuffer.removeAt(0);
    }
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

