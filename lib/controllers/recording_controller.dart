import 'dart:async';
import 'dart:developer' as dev;
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_models.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/services/csv_stream_service.dart';
import 'package:ble_app/services/eeg_parser_service.dart';
import 'package:ble_app/services/eeg_foreground_service.dart';
import 'package:ble_app/utils/extension.dart';
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
  late List<Notch50HzFilter> polysomnographyFilters;

  final RxBool isRecording = false.obs;
  final Rx<String?> currentFilePath = Rx<String?>(null);
  final RxInt sampleCount = 0.obs;
  final Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null);
  final Rx<Duration> recordingDuration = Duration.zero.obs;

  final RxList<EegSample> realtimeBuffer = <EegSample>[].obs;

  StreamSubscription? dataSubscription;
  Timer? durationTimer;

  int packetsCountInLastSecond = 0;
  int lastReceivedPacketLength = 0;

  @override
  void onInit() {
    super.onInit();
    initServices();
  }

  // init services
  void initServices() {
    final channels = settingsController.channelCount.value;
    final format = settingsController.dataFormat.value;
    final rotationMinutes = settingsController.rotationIntervalMinutes.value;
    final rotation = Duration(
      minutes: rotationMinutes > 0
          ? rotationMinutes
          : RecordingConstants.defaultRotationIntervalMinutes,
    );
    final writeChannels = format == DataFormat.int24Be
        ? RecordingConstants.csvWriteChannelCount.clamp(1, 8)
        : 1;
    csvWriter = CsvStreamWriter(
      channelCount: writeChannels,
      rotationInterval: rotation,
      outputVolts: format.outputsVolts,
    );
    parser = EegParserService(
      channelCount: format == DataFormat.int24Be ? 8 : channels,
      format: format,
    );
    polysomnographyFilters =
        List.generate(writeChannels, (_) => Notch50HzFilter());
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
    packetsCountInLastSecond = 0;
    lastReceivedPacketLength = 0;
    realtimeBuffer.clear();
    startDurationTimer();
  }

  // stop recording
  Future<void> stopRecording() async {
    await dataSubscription?.cancel();
    dataSubscription = null;
    durationTimer?.cancel();
    durationTimer = null;
    final elapsed = recordingDuration.value.inMilliseconds / 1000.0;
    await csvWriter.stopRecording(durationSeconds: elapsed > 0 ? elapsed : null);
    await stopEegForegroundService();
    isRecording.value = false;
    await Future.delayed(RecordingConstants.postStopDelay);
    recordingStartTime.value = null;
    recordingDuration.value = Duration.zero;
  }

  void onDataReceived(List<int> bytes) {
    packetsCountInLastSecond++;
    lastReceivedPacketLength = bytes.length;
    final rawSamples = parser.parseAllBytes(bytes);
    for (final rawSample in rawSamples) {
      sampleCount.value++;
      realtimeBuffer.add(rawSample);
      if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {
        realtimeBuffer.removeAt(0);
      }
      final sampleToWrite = prepareSampleForRecording(rawSample);
      csvWriter.writeSample(sampleToWrite);
    }
  }

  EegSample prepareSampleForRecording(EegSample rawSample) {
    final format = settingsController.dataFormat.value;
    if (format.outputsVolts && rawSample.channels.length > 1) {
      final maxCh = RecordingConstants.csvWriteChannelCount.clamp(1, 8);
      final filteredChannels = <double>[];
      for (int i = 0; i < rawSample.channels.length && i < maxCh; i++) {
        filteredChannels.add(
            polysomnographyFilters[i].process(rawSample.channels[i]));
      }
      return EegSample(
        timestamp: rawSample.timestamp,
        channels: filteredChannels,
      );
    }
    final rawValue =
        rawSample.channels.isNotEmpty ? rawSample.channels[0] : 0.0;
    final filteredValue = polysomnographyFilters[0].process(rawValue);
    return EegSample(
      timestamp: rawSample.timestamp,
      channels: [filteredValue],
    );
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
        if (isRecording.value && packetsCountInLastSecond > 0) {
          dev.log(
            'Recording: $packetsCountInLastSecond packets/s, lastLen=$lastReceivedPacketLength bytes, total=${sampleCount.value}',
            name: 'RecordingController',
          );
          packetsCountInLastSecond = 0;
        }
      },
    );
  }
}

