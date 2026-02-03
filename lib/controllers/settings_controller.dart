/// controller for application settings
/// handles channel count configuration and calculates bytes per sample.
/// manages eeg recording parameters used by other controllers.

import 'package:get/get.dart';
import 'package:ble_app/core/recording_constants.dart';

class SettingsController extends GetxController {
  RxInt channelCount = RxInt(1); // default to 1 channel
  static List<int> get channelOptions => RecordingConstants.channelOptions;
  void setChannelCount(int count) => channelCount.value = count; // set channel count
  int get bytesPerSample => channelCount.value * RecordingConstants.bytesPerChannel;
}
