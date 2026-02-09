import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_sample.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/services/csv_stream_service.dart';
import 'package:ble_app/services/eeg_parser_service.dart';
import 'package:ble_app/widgets/eeg_foreground_handler.dart';
import 'package:ble_app/utils/extension.dart';

// controller for recording eeg data
// handles ble data reception, parsing, and csv writing.
// manages recording state, sample buffering, and real-time data visualization.
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

  // formatted duration as HH:MM:SS
  String get formattedDuration => recordingDuration.value.toHms();

  RxList<EegSample> realtimeBuffer = <EegSample>[].obs;

  StreamSubscription? dataSubscription; 
  Timer? durationTimer; 
  bool foregroundTaskInited = false; 

  @override
  void onInit() {
    super.onInit();
    initServices();
  }

  // init services
  void initServices() {
    final channels = settingsController.channelCount.value;
    csvWriter = CsvStreamWriter(channelCount: channels);
    parser = EegParserService(
      channelCount: channels,
      format: settingsController.dataFormat.value,
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

    final dataCharacteristic = bleController.selectedDataCharacteristic;
    if (dataCharacteristic == null) {
      Get.snackbar(
        'Нет потока данных',
        'Подключите устройство. После подключения источник данных выбирается автоматически.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // start foreground task 
    if (Platform.isAndroid || Platform.isIOS) {
      await ensureForegroundTaskInited();
      await FlutterForegroundTask.startService(
        notificationTitle: 'Запись ЭЭГ',
        notificationText: 'Идёт запись. Нажмите, чтобы открыть приложение.',
        serviceTypes: [ForegroundServiceTypes.connectedDevice],
        callback: startEegForegroundCallback,
      );
    }

    // generate filename and start csv 
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final channels = settingsController.channelCount.value;
    final filename = 'eeg_${channels}ch_$timestamp.csv';
    final baseDir = settingsController.recordingDirectory.value;

    await csvWriter.startRecording(filename, baseDirectory: baseDir);
    currentFilePath.value = csvWriter.filePath; 

    await dataCharacteristic.setNotifyValue(true);
    dataSubscription = dataCharacteristic.lastValueStream.listen(onDataReceived); 

    isRecording.value = true; 
    recordingStartTime.value = DateTime.now(); 
    sampleCount.value = 0; 
    realtimeBuffer.clear(); 

    startDurationTimer(); 
  }

  // stop recording
  Future<void> stopRecording() async {
    await dataSubscription?.cancel(); 
    dataSubscription = null;
    durationTimer?.cancel(); 
    durationTimer = null;
    await csvWriter.stopRecording();
    await FlutterForegroundTask.stopService();
    isRecording.value = false;
    await Future.delayed(RecordingConstants.postStopDelay);
    recordingStartTime.value = null;
    recordingDuration.value = Duration.zero;
  }
  
  // init foreground task 
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

  // start parse bytes and write to csv
  void onDataReceived(List<int> bytes) { 
    final rawSample = parser.parseBytes(bytes);
    csvWriter.writeSample(rawSample);
    sampleCount.value++;
    realtimeBuffer.add(rawSample);
    if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {
      realtimeBuffer.removeAt(0);
    }
  }
  
  // start duration timer
  void startDurationTimer() {
    durationTimer = Timer.periodic(
      RecordingConstants.durationTimerInterval,
      (timer) {
        if (recordingStartTime.value != null) {
          recordingDuration.value =
              DateTime.now().difference(recordingStartTime.value!);
        }
      },
    );
  }
  double get sampleRate {
    if (recordingStartTime.value == null || sampleCount.value == 0) {
      return 0.0;
    }
    final elapsed = DateTime.now().difference(recordingStartTime.value!);
    if (elapsed.inSeconds == 0) return 0.0;
    return sampleCount.value / elapsed.inSeconds;
  }
}

