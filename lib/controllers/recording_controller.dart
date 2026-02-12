import 'dart:async';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_models.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/services/csv_stream_service.dart';
import 'package:ble_app/services/eeg_parser_service.dart';
import 'package:ble_app/services/eeg_foreground_service.dart';
import 'package:ble_app/utils/signal_filters.dart';

// controller for recording eeg data
// handles ble data reception, parsing, and csv writing.
// manages recording state, sample buffering, and real-time data visualization.
class RecordingController extends GetxController {

  final BleController bleController = Get.find<BleController>();
  final SettingsController settingsController = Get.find<SettingsController>();
  final FilesController filesController = Get.find<FilesController>();

  late CsvStreamWriter csvWriter;
  late EegParserService parser;
  late Notch50HzFilter polysomnographyFilter;

  final RxBool isRecording = false.obs;
  final Rx<String?> currentFilePath = Rx<String?>(null);
  final RxInt sampleCount = 0.obs;
  final Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null);
  final Rx<Duration> recordingDuration = Duration.zero.obs;

  final RxList<EegSample> realtimeBuffer = <EegSample>[].obs;

  StreamSubscription? dataSubscription;
  Timer? durationTimer;

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
    await startEegForegroundService();
    final sessionPath = await filesController.getNextSessionPath();
    await csvWriter.startRecording(
      sessionPath.filename,
      baseDirectory: sessionPath.sessionDirPath,
    );
    currentFilePath.value = csvWriter.filePath;
    await dataCharacteristic?.setNotifyValue(true);
    dataSubscription = dataCharacteristic?.lastValueStream.listen(onDataReceived);
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
    await stopEegForegroundService();
    isRecording.value = false;
    await Future.delayed(RecordingConstants.postStopDelay);
    recordingStartTime.value = null;
    recordingDuration.value = Duration.zero;
  }

  // start parse bytes and write to csv
  void onDataReceived(List<int> bytes) {

    // raw data for vizualization
    final rawSample = parser.parseBytes(bytes);
    sampleCount.value++;
    realtimeBuffer.add(rawSample);
    if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {
      realtimeBuffer.removeAt(0);
    }

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
        if (start != null) {
          recordingDuration.value = DateTime.now().difference(start);
        }
      },
    );
  }
}

