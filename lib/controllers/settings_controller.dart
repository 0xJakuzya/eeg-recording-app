import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/core/recording_constants.dart';

// controller for application settings
// manages eeg recording parameters and recording directory.
class SettingsController extends GetxController {

  static const String keyRecordingDirectory = RecordingConstants.keyRecordingDirectory; // recording directory key

  RxInt channelCount = RxInt(8); // default 8 channels
  Rx<String?> recordingDirectory = Rx<String?>(null); 

  @override
  void onInit() {
    super.onInit();
    loadRecordingDirectory();
  }
  // load recording directory from shared preferences
  Future<void> loadRecordingDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(keyRecordingDirectory);
    recordingDirectory.value = path;
  }
  // set recording directory to shared preferences
  Future<void> setRecordingDirectory(String? path) async {
    recordingDirectory.value = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(keyRecordingDirectory, path);
    } else {
      await prefs.remove(keyRecordingDirectory);
    }
  }
}
