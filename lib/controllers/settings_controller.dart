/// controller for application settings
/// handles channel count configuration and calculates bytes per sample.
/// manages eeg recording parameters used by other controllers.

import 'package:get/get.dart';
import 'package:ble_app/core/recording_constants.dart';

class SettingsController extends GetxController {
  RxInt channelCount = RxInt(8); // 8 channels
  static List<int> get channelOptions => RecordingConstants.channelOptions;
  void setChannelCount(int count) => channelCount.value = count; // kept for API consistency
  int get bytesPerSample => channelCount.value * RecordingConstants.bytesPerChannel;
}
