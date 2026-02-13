import 'dart:io';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/utils/extension.dart';

// controller for application settings
// manages eeg recording parameters and recording directory.
class SettingsController extends GetxController {

  static const String keyRecordingDirectory = RecordingConstants.keyRecordingDirectory; 
  static const String keyRotationIntervalMinutes = RecordingConstants.keyRotationIntervalMinutes;
  static const String keyLastSessionNumber = RecordingConstants.keyLastSessionNumber;
  static const String keyLastSessionDate = RecordingConstants.keyLastSessionDate;
  static const String keyDataFormat = RecordingConstants.keyDataFormat;
  static const String keySamplingRateHz = RecordingConstants.keySamplingRateHz;

  RxInt channelCount = RxInt(8); // default channels
  Rx<String?> recordingDirectory = Rx<String?>(null);
  RxInt rotationIntervalMinutes = RxInt(RecordingConstants.defaultRotationIntervalMinutes);
  RxInt lastSessionNumber = RxInt(0);
  Rx<DataFormat> dataFormat = Rx<DataFormat>(DataFormat.eeg24BitVolt);
  RxInt samplingRateHz = RxInt(RecordingConstants.defaultSamplingRateHz);
  
  @override
  void onInit() {
    super.onInit();
    loadRecordingDirectory();
    loadRotationInterval();
    loadLastSessionNumber();
    loadDataFormat();
    loadSamplingRateHz();
  }

  // load data format
  Future<void> loadDataFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(keyDataFormat);
    if (index != null && index >= 0 && index < DataFormat.values.length) {
      dataFormat.value = DataFormat.values[index];
    }
  }

  // set data format
  Future<void> setDataFormat(DataFormat format) async {
    dataFormat.value = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyDataFormat, format.index);
  }

  // load sampling rate
  Future<void> loadSamplingRateHz() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keySamplingRateHz);
    if (value != null &&
        RecordingConstants.supportedSamplingRates.contains(value)) {
      samplingRateHz.value = value;
    }
  }

  // set sampling rate and optionally send to device
  Future<void> setSamplingRateHz(int hz) async {
    if (!RecordingConstants.supportedSamplingRates.contains(hz)) return;
    samplingRateHz.value = hz;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keySamplingRateHz, hz);
  }

  // send command to EEG device (requires BleController)
  Future<bool> sendDeviceCommand(String command) async {
    try {
      final ble = Get.find<BleController>();
      return await ble.sendCommand(command);
    } catch (_) {
      return false;
    }
  }

  /// Sends sampling rate command (d50, d100, d250, d500, d1000)
  Future<bool> applySamplingRateToDevice() async {
    final cmd = 'd${samplingRateHz.value}';
    return sendDeviceCommand(cmd);
  }

  /// Start data transmission
  Future<bool> sendStartTransmission() async => sendDeviceCommand('start');

  /// Stop data transmission
  Future<bool> sendStopTransmission() async => sendDeviceCommand('stop');

  /// Ping device
  Future<bool> sendPing() async => sendDeviceCommand('ping');

  // load recording directory
  Future<void> loadRecordingDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(keyRecordingDirectory);
    recordingDirectory.value = path;
  }

  // set recording directory 
  Future<void> setRecordingDirectory(String? path) async {
    recordingDirectory.value = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {await prefs.setString(keyRecordingDirectory, path);} 
    else {await prefs.remove(keyRecordingDirectory);}
  }

  // load rotation interval in minutes
  Future<void> loadRotationInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keyRotationIntervalMinutes);
    if (value != null && value > 0) { rotationIntervalMinutes.value = value;}
  }

  // set rotation interval in minutes
  Future<void> setRotationIntervalMinutes(int minutes) async {
    rotationIntervalMinutes.value = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyRotationIntervalMinutes, minutes);
  }

  // load last session number
  Future<void> loadLastSessionNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keyLastSessionNumber);
    if (value != null && value >= 0) {lastSessionNumber.value = value;}
  }

  // get next session number 
  Future<int> getNextSessionNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentDate = now.format('dd.MM.yyyy');
    final lastDate = prefs.getString(keyLastSessionDate);
    
    int next;
    if (lastDate != null && lastDate == currentDate) {
      final current = prefs.getInt(keyLastSessionNumber) ?? 0;
      next = current + 1;
    } else {
      next = 1;
    }
    
    await prefs.setInt(keyLastSessionNumber, next);
    await prefs.setString(keyLastSessionDate, currentDate);
    lastSessionNumber.value = next;
    return next;
  }

  // recalculate session number based on existing directories
  Future<int> recalculateSessionNumber(String dateFolderPath) async {
    final dir = Directory(dateFolderPath);
    if (!await dir.exists()) {
      return 1;
    }
    
    final sessionDirs = <int>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        final match = RegExp(r'^session_(\d+)$').firstMatch(name);
        if (match != null) {
          final number = int.tryParse(match.group(1)!);
          if (number != null) {
            sessionDirs.add(number);
          }
        }
      }
    }
    
    if (sessionDirs.isEmpty) {
      return 1;
    }
    
    sessionDirs.sort();
    final maxNumber = sessionDirs.last;
    return maxNumber + 1;
  }

  // reset session counter for current date
  Future<void> resetSessionCounterForDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(keyLastSessionDate);
    if (lastDate == date) {
      await prefs.setInt(keyLastSessionNumber, 0);
      lastSessionNumber.value = 0;
    }
  }
}
