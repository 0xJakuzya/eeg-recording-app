import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:ble_app/features/ble/ble_controller.dart';
import 'package:ble_app/features/files/files_controller.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/core/common/eeg_sample.dart';
import 'package:ble_app/core/constants/ble_constants.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/features/recording/csv_stream_service.dart';
import 'package:ble_app/features/recording/eeg_stream_parser.dart';
import 'package:ble_app/features/recording/eeg_foreground_service.dart';
import 'package:ble_app/core/utils/signal_filters.dart';

// ble data → parser → csv + realtime buffer; manages foreground service and duration timer
class RecordingController extends GetxController {
  final BleController bleController = Get.find<BleController>();
  final SettingsController settingsController = Get.find<SettingsController>();
  final FilesController filesController = Get.find<FilesController>();

  late CsvStreamWriter csvWriter;
  late EegStreamParser parser;
  late EegDisplayFilter displayFilter;

  final RxBool isRecording = false.obs;
  final Rx<String?> currentFilePath = Rx<String?>(null);
  final RxInt sampleCount = 0.obs;
  final Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null);
  final Rx<Duration> recordingDuration = Duration.zero.obs;

  final RxList<EegSample> realtimeBuffer = <EegSample>[].obs;

  final RxBool isChannelSignalFlat = false.obs;
  final RxBool isPreparing = false.obs;

  StreamSubscription? dataSubscription;
  Timer? durationTimer;

  int packetsCountInLastSecond = 0;
  int lastReceivedPacketLength = 0;
  int _recordingStartMs = 0;
  int _bleChunkCount = 0;

  @override
  void onInit() {
    super.onInit();
    initServices();
  }

  void initServices() {
    final rotationMinutes = settingsController.rotationIntervalMinutes.value;
    final rotation = Duration(
      minutes: rotationMinutes > 0
          ? rotationMinutes
          : RecordingConstants.defaultRotationIntervalMinutes,
    );
    final fmt = settingsController.recordingFileExtension.value;
    csvWriter = CsvStreamWriter(
      rotationInterval: rotation,
      fileExtension: settingsController.effectiveFileExtension,
      isPolysomnographyFormat: fmt == RecordingConstants.formatPolysomnography,
    );
    parser = EegStreamParser(vRef: RecordingConstants.adcVrefVolts);
    displayFilter = EegDisplayFilter(
      samplingFreqHz: RecordingConstants.samplingRateHz,
    );
  }

  @override
  void onClose() {
    stopRecording();
    super.onClose();
  }

  Future<void> startRecording() async {
    initServices();
    _bleChunkCount = 0;
    final dataCharacteristic = bleController.selectedDataCharacteristic;
    if (dataCharacteristic == null) {
      print('[EEG] ERROR: No data characteristic - connect device first.');
      dev.log('ERROR: No data characteristic selected',
          name: 'RecordingController');
      return;
    }
    print('[EEG] 1.START: subscribe to ${dataCharacteristic.uuid.str}');
    dev.log('Recording: subscribing to ${dataCharacteristic.uuid.str}',
        name: 'RecordingController');
    await startEegForegroundService();
    final sessionPath = await filesController.getNextSessionPath();
    await csvWriter.startRecording(
      sessionPath.filename,
      baseDirectory: sessionPath.sessionDirPath,
    );
    currentFilePath.value = csvWriter.filePath;
    try {
      await dataCharacteristic.setNotifyValue(true);
    } catch (e) {
      print('[EEG] ERROR: setNotifyValue failed: $e');
      dev.log('setNotifyValue failed: $e', name: 'RecordingController');
      return;
    }
    _recordingStartMs = DateTime.now().millisecondsSinceEpoch;
    dataSubscription = dataCharacteristic.lastValueStream.listen(onDataReceived);
    isPreparing.value = true;
    try {
      await _initDeviceTransmission();
    } finally {
      isPreparing.value = false;
    }
    isRecording.value = true;
    recordingStartTime.value = DateTime.now();
    sampleCount.value = 0;
    packetsCountInLastSecond = 0;
    lastReceivedPacketLength = 0;
    realtimeBuffer.clear();
    displayFilter.reset();
    parser.reset();
    startDurationTimer();
  }

  // stop → set sample rate → start, with retry; verifies data is flowing
  Future<void> _initDeviceTransmission() async {
    const cmdDelay = Duration(milliseconds: 300);
    const dataWaitTimeout = Duration(seconds: 2);
    const maxStartAttempts = 3;

    final sampleRateCmd = settingsController.samplingRateCommand;
    await bleController.sendCommandWithRetry(BleConstants.cmdStopTransmission);
    await Future.delayed(cmdDelay);
    await bleController.sendCommandWithRetry(sampleRateCmd);
    await Future.delayed(cmdDelay);

    for (int attempt = 1; attempt <= maxStartAttempts; attempt++) {
      final countBefore = sampleCount.value;
      await bleController.sendCommandWithRetry(BleConstants.cmdStartTransmission);

      // wait for data to arrive
      final deadline = DateTime.now().add(dataWaitTimeout);
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (sampleCount.value > countBefore) {
          dev.log('Device started on attempt $attempt', name: 'RecordingController');
          return;
        }
      }
      dev.log('No data after start attempt $attempt/$maxStartAttempts, retrying...',
          name: 'RecordingController');
      // re-send stop + start
      await bleController.sendCommandWithRetry(BleConstants.cmdStopTransmission);
      await Future.delayed(cmdDelay);
    }
    dev.log('WARNING: device may not be transmitting after $maxStartAttempts attempts',
        name: 'RecordingController');
  }

  Future<void> stopRecording() async {
    if (RecordingConstants.eegDataFlowDebug) {
      print('[EEG] STOP: total=${sampleCount.value} samples, $_bleChunkCount BLE chunks');
    }
    await dataSubscription?.cancel();
    dataSubscription = null;
    await bleController.sendCommand(BleConstants.cmdStopTransmission);
    durationTimer?.cancel();
    durationTimer = null;
    await csvWriter.stopRecording();
    await stopEegForegroundService();
    isRecording.value = false;
    await Future.delayed(RecordingConstants.postStopDelay);
    recordingStartTime.value = null;
    recordingDuration.value = Duration.zero;
    isChannelSignalFlat.value = false;
  }

  void onDataReceived(List<int> bytes) {
    packetsCountInLastSecond++;
    lastReceivedPacketLength = bytes.length;
    _bleChunkCount++;

    final chunk = Uint8List.fromList(bytes);
    final rawSamples = parser.parseChunk(chunk, _recordingStartMs);

    if (RecordingConstants.eegDataFlowDebug) {
      final hex = bytes.take(14).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ');
      if (_bleChunkCount <= 5 || _bleChunkCount % 50 == 1 || rawSamples.isNotEmpty) {
        print('[EEG] 2.BLE chunk #$_bleChunkCount: ${bytes.length}b → $hex${bytes.length > 14 ? '...' : ''}');
      }
      if (rawSamples.isNotEmpty) {
        print('[EEG] 3.PARSER: ${rawSamples.length} samples (total=${sampleCount.value + rawSamples.length})');
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final rawSample in rawSamples) {
      sampleCount.value++;
      final volts = RecordingConstants.applyFilterOnRecording
          ? displayFilter.process(rawSample.volts)
          : rawSample.volts;
      final sampleToWrite = EegSample(
        header: rawSample.header,
        sequence: rawSample.sequence,
        battery: rawSample.battery,
        dataMsb: rawSample.dataMsb,
        dataMid: rawSample.dataMid,
        dataLsb: rawSample.dataLsb,
        footer: rawSample.footer,
        rawValue: rawSample.rawValue,
        volts: volts,
        timestampMs: rawSample.timestampMs,
      );
      realtimeBuffer.add(sampleToWrite);
      if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {
        realtimeBuffer.removeAt(0);
      }
      csvWriter.writeSample(sampleToWrite, nowMs);
    }
    _validateChannelSignal();
  }

  void _validateChannelSignal() {
    const window = RecordingConstants.eegValidationWindowSamples;
    const threshold = RecordingConstants.eegFlatSignalVarianceThreshold;
    final buffer = realtimeBuffer;
    if (buffer.length < window) return;
    double sum = 0, sumSq = 0;
    for (int i = buffer.length - window; i < buffer.length; i++) {
      final v = buffer[i].volts;
      sum += v;
      sumSq += v * v;
    }
    final mean = sum / window;
    final variance = (sumSq / window) - (mean * mean);
    isChannelSignalFlat.value = variance < threshold;
  }

  void startDurationTimer() {
    durationTimer = Timer.periodic(
      RecordingConstants.durationTimerInterval,
      (timer) {
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
