// controller for settings
// handles channel count and bytes per sample

import 'package:get/get.dart';

class SettingsController extends GetxController {
  RxInt channelCount = RxInt(1); // default to 1 channel
  static const List<int> channelOptions = [1, 2, 4, 8];
  void setChannelCount(int count) => channelCount.value = count; // set channel count
  int get bytesPerSample => channelCount.value * 2; // 2 bytes per channel
}
