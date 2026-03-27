import 'dart:io';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/core/constants/ble_constants.dart';
import 'package:ble_app/core/constants/polysomnography_constants.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/features/ble/ble_controller.dart';

// controller responsible for EEG recording params, polysomnography URL
// GetX reactive state; persists via shared_preferences; delegates BLE commands to BleController
class SettingsController extends GetxController {
  static const String keyRecordingDirectory =
      RecordingConstants.keyRecordingDirectory;
  static const String keyRecordingFileExtension = 'recording_file_extension';
  static const String keyRotationIntervalMinutes =
      RecordingConstants.keyRotationIntervalMinutes;
  static const String keyLastSessionNumber =
      RecordingConstants.keyLastSessionNumber;
  static const String keyPolysomnographyBaseUrl = 'polysomnography_base_url';
  static const String keySamplingRateHz = 'sampling_rate_hz';

  Rx<String?> recordingDirectory = Rx<String?>(null);
  RxInt rotationIntervalMinutes =
      RxInt(RecordingConstants.defaultRotationIntervalMinutes);
  RxInt lastSessionNumber = RxInt(0);
  Rx<String> recordingFileExtension = RecordingConstants.formatPolysomnography.obs;
  Rx<String?> polysomnographyBaseUrl = Rx<String?>(null);
  RxInt recordingSamplingRateHz = RxInt(BleConstants.defaultRecordingSampleRateHz);

  int get samplingRateHz => RecordingConstants.samplingRateHz;

  @override
  void onInit() {
    super.onInit();
    loadRecordingDirectory();
    loadRecordingFileExtension();
    loadRotationInterval();
    loadLastSessionNumber();
    loadPolysomnographyBaseUrl();
    loadSamplingRate();
  }

  // fallback to default when empty/null
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

  // BLE command for the selected sampling rate
  String get samplingRateCommand =>
      BleConstants.sampleRateCommands[recordingSamplingRateHz.value] ?? BleConstants.cmdD100;

  Future<void> loadSamplingRate() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(keySamplingRateHz);
    if (stored != null && BleConstants.availableSampleRates.contains(stored)) {
      recordingSamplingRateHz.value = stored;
    }
  }

  Future<void> setSamplingRate(int hz) async {
    if (!BleConstants.availableSampleRates.contains(hz)) return;
    recordingSamplingRateHz.value = hz;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keySamplingRateHz, hz);
  }

  String get effectiveFileExtension {
    if (recordingFileExtension.value == RecordingConstants.formatPolysomnography) return '.txt';
    return recordingFileExtension.value;
  }

  Future<void> loadRecordingFileExtension() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(keyRecordingFileExtension);
    if (stored == RecordingConstants.formatPolysomnography) {
      recordingFileExtension.value = stored!;
    }
  }

  Future<void> setRecordingFileExtension(String ext) async {
    if (!RecordingConstants.validFileFormats.contains(ext)) return;
    recordingFileExtension.value = ext;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyRecordingFileExtension, ext);
  }

  BleController? get bleController =>
      Get.isRegistered<BleController>() ? Get.find<BleController>() : null;

  Future<bool> sendD100() async {
    final ble = bleController;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdD100);
  }

  Future<bool> sendD250() async {
    final ble = bleController;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdD250);
  }

  Future<bool> sendD500() async {
    final ble = bleController;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdD500);
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

  Future<void> resetSessionCounterForDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(RecordingConstants.keyLastSessionDate);
    if (lastDate == date) {
      await prefs.remove(RecordingConstants.keyLastSessionDate);
      await prefs.setInt(keyLastSessionNumber, 0);
      lastSessionNumber.value = 0;
    }
  }

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
