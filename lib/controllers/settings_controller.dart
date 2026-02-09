import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/core/data_format.dart';

// controller for application settings
// manages eeg recording parameters, data format and recording directory.
class SettingsController extends GetxController {

  static const String keyRecordingDirectory =
      RecordingConstants.keyRecordingDirectory; 
  static const String keyDataFormat = 'eeg_data_format'; 

  RxInt channelCount = RxInt(8); // default 8 channels
  Rx<String?> recordingDirectory = Rx<String?>(null);

  Rx<DataFormat> dataFormat = DataFormat.uint12Le.obs;
  
  @override
  void onInit() {
    super.onInit();
    loadRecordingDirectory();
    loadDataFormat();
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
    if (path != null) {
      await prefs.setString(keyRecordingDirectory, path);
    } else {
      await prefs.remove(keyRecordingDirectory);
    }
  }
  // load data format 
  Future<void> loadDataFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(keyDataFormat);
    if (stored != null) {
      dataFormat.value = DataFormat.values.firstWhere(
        (f) => f.name == stored,
        orElse: () => DataFormat.uint12Le,
      );
    }
  }
  // set data format 
  Future<void> setDataFormat(DataFormat format) async {
    dataFormat.value = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDataFormat, format.name);
  }
}
