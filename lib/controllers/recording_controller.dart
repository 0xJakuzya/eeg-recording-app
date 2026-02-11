import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_sample.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/services/csv_stream_service.dart';
import 'package:ble_app/services/eeg_parser_service.dart';
import 'package:ble_app/widgets/eeg_foreground_handler.dart';
import 'package:ble_app/utils/extension.dart';
import 'package:ble_app/utils/signal_filters.dart';

// controller for recording eeg data
// handles ble data reception, parsing, and csv writing.
// manages recording state, sample buffering, and real-time data visualization.
class RecordingController extends GetxController {
  final BleController bleController = Get.find<BleController>();
  final SettingsController settingsController = Get.find<SettingsController>();

  late CsvStreamWriter csvWriter;
  late EegParserService parser;
  late Notch50HzFilter polysomnographyFilter;

  final RxBool isRecording = false.obs;
  final Rx<String?> currentFilePath = Rx<String?>(null);
  final RxInt sampleCount = 0.obs;
  final Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null);
  final Rx<Duration> recordingDuration = Duration.zero.obs;

  String get formattedDuration => recordingDuration.value.toHms();
  final RxList<EegSample> realtimeBuffer = <EegSample>[].obs;

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
    final rotationMinutes = settingsController.rotationIntervalMinutes.value;
    final rotation = Duration(
      minutes: rotationMinutes > 0
          ? rotationMinutes
          : RecordingConstants.defaultRotationIntervalMinutes,
    );
    csvWriter = CsvStreamWriter(
      channelCount: 1, // 1 channel for write
      rotationInterval: rotation,
    );
    parser = EegParserService(
      channelCount: channels,
      format: settingsController.dataFormat.value,
    );
    // notch filter 50 Hz for write files
    polysomnographyFilter = Notch50HzFilter();
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

    final now = DateTime.now();
    final rootDir = await resolveRootDir();
    final dateFolderName = now.format('dd.MM.yyyy');
    final dateDirPath = joinPath(rootDir, dateFolderName);
    final sessionNumber = await settingsController.getNextSessionNumber();
    final sessionFolderName = 'session_$sessionNumber';
    final sessionDirPath = joinPath(dateDirPath, sessionFolderName);
    await Directory(sessionDirPath).create(recursive: true);
    final filename = 'session_$sessionNumber${RecordingConstants.recordingFileExtension}';

    await csvWriter.startRecording(filename, baseDirectory: sessionDirPath);
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
    final notifPerm =
        await FlutterForegroundTask.checkNotificationPermission();
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

    // raw data for vizualization
    final rawSample = parser.parseBytes(bytes);
    sampleCount.value++;
    realtimeBuffer.add(rawSample);
    if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {realtimeBuffer.removeAt(0);}

    // processed data for service polysomnography
    final rawValue = rawSample.channels.isNotEmpty ? rawSample.channels[0] : 0.0;
    final filteredValue = polysomnographyFilter.process(rawValue);
    final filteredSample = EegSample(
      timestamp: rawSample.timestamp,
      channels: [filteredValue],
    );
    csvWriter.writeSample(filteredSample); // write processed data in .txt
  }

  // start duration timer
  void startDurationTimer() {
    durationTimer = Timer.periodic(
      RecordingConstants.durationTimerInterval,
      (_) {
        final start = recordingStartTime.value;
        if (start != null) {recordingDuration.value = DateTime.now().difference(start);}
      },
    );
  }

  double get sampleRate {
    final start = recordingStartTime.value;
    if (start == null || sampleCount.value == 0) return 0.0;
    final elapsed = DateTime.now().difference(start);
    if (elapsed.inSeconds == 0) return 0.0;
    return sampleCount.value / elapsed.inSeconds;
  }

  Future<String> resolveRootDir() async {
    final customDir = settingsController.recordingDirectory.value;
    if (customDir != null && customDir.isNotEmpty) return customDir;
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  String joinPath(String parent, String child) => parent.endsWith(Platform.pathSeparator)
          ? '$parent$child'
          : '$parent${Platform.pathSeparator}$child';
}

