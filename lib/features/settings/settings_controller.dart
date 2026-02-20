import 'dart:io';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/core/constants/ble_constants.dart';
import 'package:ble_app/core/constants/polysomnography_constants.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/features/ble/ble_controller.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

/// Controller for application settings.
/// Manages EEG recording parameters, data format, and recording directory.
class SettingsController extends GetxController {
  static const String keyRecordingDirectory =
      RecordingConstants.keyRecordingDirectory;
  static const String keyDataFormat = 'eeg_data_format';
  static const String keyRecordingFileExtension = 'recording_file_extension';
  static const String keyRecordingChannelCount = 'recording_channel_count';
  static const String keyRotationIntervalMinutes =
      RecordingConstants.keyRotationIntervalMinutes;
  static const String keyLastSessionNumber =
      RecordingConstants.keyLastSessionNumber;
  static const String keySamplingRateHz = 'sampling_rate_hz';
  static const String keyPolysomnographyBaseUrl = 'polysomnography_base_url';

  RxInt channelCount = RxInt(8);
  RxInt samplingRateHz = RxInt(RecordingConstants.samplingRateDefaultHz);
  Rx<String?> recordingDirectory = Rx<String?>(null);
  RxInt rotationIntervalMinutes =
      RxInt(RecordingConstants.defaultRotationIntervalMinutes);
  RxInt lastSessionNumber = RxInt(0);
  Rx<DataFormat> dataFormat = DataFormat.int24Be.obs;
  Rx<String> recordingFileExtension = '.txt'.obs;
  RxInt recordingChannelCount = RxInt(1);
  Rx<String?> polysomnographyBaseUrl = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    loadRecordingDirectory();
    loadDataFormat();
    loadRecordingFileExtension();
    loadRecordingChannelCount();
    loadRotationInterval();
    loadSamplingRate();
    loadLastSessionNumber();
    loadPolysomnographyBaseUrl();
  }

  String get effectivePolysomnographyBaseUrl {
    final url = polysomnographyBaseUrl.value?.trim();
    if (url == null || url.isEmpty) {
      return PolysomnographyConstants.defaultBaseUrl;
    }
    return url;
  }

  Future<void> loadPolysomnographyBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    polysomnographyBaseUrl.value = prefs.getString(keyPolysomnographyBaseUrl);
  }

  Future<void> setPolysomnographyBaseUrl(String? url) async {
    final trimmed = url?.trim();
    polysomnographyBaseUrl.value =
        trimmed?.isEmpty ?? true ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (polysomnographyBaseUrl.value != null) {
      await prefs.setString(
          keyPolysomnographyBaseUrl, polysomnographyBaseUrl.value!);
    } else {
      await prefs.remove(keyPolysomnographyBaseUrl);
    }
  }

  Future<void> loadRecordingDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(keyRecordingDirectory);
    recordingDirectory.value = path;
  }

  Future<void> setRecordingDirectory(String? path) async {
    recordingDirectory.value = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(keyRecordingDirectory, path);
    } else {
      await prefs.remove(keyRecordingDirectory);
    }
  }

  Future<void> loadRotationInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keyRotationIntervalMinutes);
    if (value != null && value > 0) {
      rotationIntervalMinutes.value = value;
    }
  }

  Future<void> setRotationIntervalMinutes(int minutes) async {
    rotationIntervalMinutes.value = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyRotationIntervalMinutes, minutes);
  }

  Future<void> loadLastSessionNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keyLastSessionNumber);
    if (value != null && value >= 0) {
      lastSessionNumber.value = value;
    }
  }

  Future<void> setLastSessionNumber(int value) async {
    final clamped = value < 0 ? 0 : value;
    lastSessionNumber.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyLastSessionNumber, clamped);
  }

  Future<int> getNextSessionNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(keyLastSessionNumber) ?? 0;
    final next = current + 1;
    await prefs.setInt(keyLastSessionNumber, next);
    lastSessionNumber.value = next;
    return next;
  }

  Future<void> loadDataFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(keyDataFormat);
    if (stored != null) {
      dataFormat.value = DataFormat.values.firstWhere(
        (f) => f.name == stored,
        orElse: () => DataFormat.int24Be,
      );
    }
  }

  Future<void> setDataFormat(DataFormat format) async {
    dataFormat.value = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDataFormat, format.name);
  }

  Future<void> loadRecordingFileExtension() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(keyRecordingFileExtension);
    if (stored != null && (stored == '.txt' || stored == '.csv')) {
      recordingFileExtension.value = stored;
    }
  }

  Future<void> setRecordingFileExtension(String ext) async {
    if (ext != '.txt' && ext != '.csv') return;
    recordingFileExtension.value = ext;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyRecordingFileExtension, ext);
  }

  Future<void> loadRecordingChannelCount() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keyRecordingChannelCount);
    if (value != null && value >= 1 && value <= 8) {
      recordingChannelCount.value = value;
    }
  }

  Future<void> setRecordingChannelCount(int count) async {
    final clamped = count.clamp(1, 8);
    recordingChannelCount.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyRecordingChannelCount, clamped);
  }

  Future<void> loadSamplingRate() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keySamplingRateHz);
    if (value != null &&
        value >= RecordingConstants.samplingRateMinHz &&
        value <= RecordingConstants.samplingRateMaxHz) {
      samplingRateHz.value = value;
    }
  }

  Future<void> setSamplingRate(int hz) async {
    final clamped = hz.clamp(
      RecordingConstants.samplingRateMinHz,
      RecordingConstants.samplingRateMaxHz,
    );
    samplingRateHz.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keySamplingRateHz, clamped);
  }

  BleController? get bleController =>
      Get.isRegistered<BleController>() ? Get.find<BleController>() : null;

  Future<bool> applySamplingRateToDevice() async {
    final ble = bleController;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdSetSamplingRate(samplingRateHz.value));
  }

  Future<bool> sendPing() async {
    final ble = bleController;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdPing);
  }

  Future<bool> sendStartTransmission() async {
    final ble = bleController;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdStartTransmission);
  }

  Future<bool> sendStopTransmission() async {
    final ble = bleController;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdStopTransmission);
  }

  /// Resets the session counter for a specific date.
  /// This is called when a date folder is deleted.
  Future<void> resetSessionCounterForDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(RecordingConstants.keyLastSessionDate);
    if (lastDate == date) {
      // If the deleted date was the last session date, reset the counter
      await prefs.remove(RecordingConstants.keyLastSessionDate);
      await prefs.setInt(keyLastSessionNumber, 0);
      lastSessionNumber.value = 0;
    }
  }

  /// Recalculates the maximum session number for a given parent directory path.
  /// Returns the maximum session number found in that directory.
  Future<int> recalculateSessionNumber(String parentPath) async {
    final dir = Directory(parentPath);
    if (!await dir.exists()) return 0;

    int maxSession = 0;
    final sessionFolderPattern = RegExp(r'^session_(\d+)$');

    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is! Directory) continue;
      final sessionName = entity.path.split(Platform.pathSeparator).last;
      final match = sessionFolderPattern.firstMatch(sessionName);
      if (match != null) {
        final n = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (n > maxSession) maxSession = n;
      }
    }

    return maxSession;
  }
}
