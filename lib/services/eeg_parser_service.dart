// service for parsing raw ble bytes into eeg samples
// supports configurable channel count (1-8)

import 'package:ble_app/models/eeg_sample.dart';

class EegParserService {
  
  final int channelCount;
  static const int bytesPerChannel = 2; // 2 bytes per channel
  EegParserService({this.channelCount = 1}); // default to 1 channel
  int get expectedPacketSize => channelCount * bytesPerChannel;

  EegSample parseBytes(List<int> bytes) {
    final channels = <double>[];
    final timestamp = DateTime.now();

    for (int i = 0; i < channelCount; i++) {
      final byteIndex = i * bytesPerChannel;

      int value = bytes[byteIndex] | (bytes[byteIndex + 1] << 8);
      if (value > 32767) { value -= 65536; }

      final voltage = value.toDouble();
      channels.add(voltage);
    }
    return EegSample(timestamp: timestamp, channels: channels); 
  }
}
