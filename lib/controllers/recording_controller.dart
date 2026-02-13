import 'dart:async';

import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/models/eeg_models.dart';
import 'package:ble_app/widgets/eeg_plots.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/core/polysomnography_constants.dart';
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
  late List<Notch50HzFilter> polysomnographyFilters;

  final RxBool isRecording = false.obs;
  final Rx<String?> currentFilePath = Rx<String?>(null);
  final RxInt sampleCount = 0.obs;
  final Rx<DateTime?> recordingStartTime = Rx<DateTime?>(null);
  final Rx<Duration> recordingDuration = Duration.zero.obs;

  final RxList<EegSample> realtimeBuffer = <EegSample>[].obs;

  /// Зафиксированный след (завершённый проход 0..window)
  final RxList<List<EegDataPoint>> persistedChartData = <List<EegDataPoint>>[].obs;
  /// База времени для текущего прохода
  DateTime? sweepTimeRef;

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
      channelCount: channels,
      rotationInterval: rotation,
    );

    parser = EegParserService(
      channelCount: channels,
      format: PolysomnographyConstants.defaultEegDataFormat,
    );

    // notch filter 50 Hz per channel для CSV (график — сырой сигнал)
    polysomnographyFilters =
        List.generate(channels, (_) => Notch50HzFilter());
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
    persistedChartData.clear();
    sweepTimeRef = DateTime.now();
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
    persistedChartData.clear();
    sweepTimeRef = null;
  }

  (List<List<EegDataPoint>> persisted, List<List<EegDataPoint>> current)
      getChartData(double windowSeconds, int channelCount) {
    final buffer = realtimeBuffer;
    if (buffer.isEmpty) {
      return (persistedChartData.toList(), <List<EegDataPoint>>[]);
    }

    final ref = sweepTimeRef ?? recordingStartTime.value ?? buffer.first.timestamp;
    final windowSec = windowSeconds;

    final pointsWithTime = buffer.map((s) {
      final sec = (s.timestamp.difference(ref).inMilliseconds) / 1000.0;
      return (sample: s, time: sec);
    }).toList();

    final maxTime = pointsWithTime.isNotEmpty ? pointsWithTime.last.time : 0.0;

    if (maxTime >= windowSec) {
      final completed = pointsWithTime.where((e) => e.time < windowSec).toList();
      final overflow = pointsWithTime.where((e) => e.time >= windowSec).toList();
      if (completed.isNotEmpty) {
        persistedChartData.clear();
        persistedChartData.addAll(List.generate(channelCount, (ch) {
          return completed.map((e) {
            final displayCh = e.sample.channelsForDisplay;
            final amp = ch < displayCh.length ? displayCh[ch] : 0.0;
            return EegDataPoint(time: e.time, amplitude: amp);
          }).toList();
        }));
      }
      if (overflow.isNotEmpty) {
        final newRef = overflow.first.sample.timestamp;
        sweepTimeRef = newRef;
        realtimeBuffer.removeWhere((s) => s.timestamp.isBefore(newRef));
      }
      return (
        persistedChartData.toList(),
        _buildCurrentFromBuffer(windowSec, channelCount),
      );
    }

    final current = _buildCurrentFromBuffer(windowSec, channelCount);
    return (persistedChartData.toList(), current);
  }

  List<List<EegDataPoint>> _buildCurrentFromBuffer(
      double windowSec, int channelCount) {
    final buffer = realtimeBuffer;
    final ref = sweepTimeRef ?? recordingStartTime.value;
    if (buffer.isEmpty || ref == null) return <List<EegDataPoint>>[];

    return List.generate(channelCount, (ch) {
      return buffer.map((s) {
        final sec = (s.timestamp.difference(ref).inMilliseconds) / 1000.0;
        if (sec < 0 || sec > windowSec) return null;
        final displayCh = s.channelsForDisplay;
        final amp = ch < displayCh.length ? displayCh[ch] : 0.0;
        return EegDataPoint(time: sec, amplitude: amp);
      }).whereType<EegDataPoint>().toList();
    });
  }

  // start parse bytes and write to csv
  void onDataReceived(List<int> bytes) {
    final rawSample = parser.parseBytes(bytes);
    // пропускаем пустые сэмплы (нет полного кадра 24-бит)
    if (rawSample.channels.isEmpty) return;

    sampleCount.value++;

    // фильтруем каналы для CSV (вольты)
    final filteredChannels = <double>[];
    for (var ch = 0; ch < rawSample.channels.length; ch++) {
      final f = ch < polysomnographyFilters.length
          ? polysomnographyFilters[ch]
          : polysomnographyFilters[0];
      filteredChannels.add(f.process(rawSample.channels[ch]));
    }

    final filteredSample = EegSample(
      timestamp: rawSample.timestamp,
      channels: filteredChannels,
      rawChannels: rawSample.rawChannels,
    );
    realtimeBuffer.add(rawSample);
    if (realtimeBuffer.length > RecordingConstants.realtimeBufferMaxSize) {
      realtimeBuffer.removeAt(0);
    }
    csvWriter.writeSample(filteredSample);
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

