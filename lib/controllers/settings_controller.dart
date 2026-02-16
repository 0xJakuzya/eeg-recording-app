import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/core/ble_constants.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/utils/extension.dart';

// controller for application settings
// manages eeg recording parameters, data format and recording directory.
class SettingsController extends GetxController {

  static const String keyRecordingDirectory = RecordingConstants.keyRecordingDirectory; 
  static const String keyDataFormat = 'eeg_data_format'; 
  static const String keyRotationIntervalMinutes = RecordingConstants.keyRotationIntervalMinutes;
  static const String keyLastSessionNumber = RecordingConstants.keyLastSessionNumber;
  static const String keySamplingRateHz = 'sampling_rate_hz';

  RxInt channelCount = RxInt(8); // default channels
  Rx<String?> recordingDirectory = Rx<String?>(null);
  RxInt rotationIntervalMinutes = RxInt(RecordingConstants.defaultRotationIntervalMinutes);
  RxInt lastSessionNumber = RxInt(0);
  Rx<DataFormat> dataFormat = DataFormat.uint12Le.obs;
  RxInt samplingRateHz = RxInt(RecordingConstants.defaultSamplingRateHz);

  @override
  void onInit() {
    super.onInit();
    loadRecordingDirectory();
    loadDataFormat();
    loadRotationInterval();
    loadLastSessionNumber();
    loadSamplingRate();
  }

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
    final current = prefs.getInt(keyLastSessionNumber) ?? 0;
    final next = current + 1;
    await prefs.setInt(keyLastSessionNumber, next);
    lastSessionNumber.value = next;
    return next;
  }

  // load data format 
  Future<void> loadDataFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(keyDataFormat);
    if (stored != null) {dataFormat.value = DataFormat.values.firstWhere (
        (f) => f.name == stored,
        orElse: () => DataFormat.uint12Le,
      );}
  }

  // set data format
  Future<void> setDataFormat(DataFormat format) async {
    dataFormat.value = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDataFormat, format.name);
  }

  // load sampling rate
  Future<void> loadSamplingRate() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(keySamplingRateHz);
    if (value != null &&
        RecordingConstants.supportedSamplingRates.contains(value)) {
      samplingRateHz.value = value;
    }
  }

  // set sampling rate
  Future<void> setSamplingRateHz(int hz) async {
    if (!RecordingConstants.supportedSamplingRates.contains(hz)) return;
    samplingRateHz.value = hz;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keySamplingRateHz, hz);
  }

  /// Sends sampling rate to connected BLE device. Returns true on success.
  Future<bool> applySamplingRateToDevice() async {
    final ble = Get.isRegistered<BleController>() ? Get.find<BleController>() : null;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdSetSamplingRate(samplingRateHz.value));
  }

  Future<bool> sendPing() async {
    final ble = Get.isRegistered<BleController>() ? Get.find<BleController>() : null;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdPing);
  }

  Future<bool> sendStartTransmission() async {
    final ble = Get.isRegistered<BleController>() ? Get.find<BleController>() : null;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdStartTransmission);
  }

  Future<bool> sendStopTransmission() async {
    final ble = Get.isRegistered<BleController>() ? Get.find<BleController>() : null;
    if (ble == null) return false;
    return ble.sendCommand(BleConstants.cmdStopTransmission);
  }
}
