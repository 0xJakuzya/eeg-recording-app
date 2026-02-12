import 'package:ble_app/utils/extension.dart';
import 'package:ble_app/models/eeg_models.dart';

/// Service for parsing raw BLE bytes into EEG samples.
class EegParserService {
  
  EegParserService({
    this.channelCount = 1,
    this.format = DataFormat.uint12Le,
  });

  final int channelCount;
  final DataFormat format;
  int get bytesPerChannel => format.bytesPerChannel;
  int get expectedPacketSize => channelCount * bytesPerChannel;

  EegSample parseBytes(List<int> bytes) {

    final channels = <double>[];
    final timestamp = DateTime.now();
    final availableBytes = bytes.length - 1;
    final maxChannelsFromPacket = availableBytes ~/ bytesPerChannel;
    final parsedChannelCount = maxChannelsFromPacket < channelCount ? maxChannelsFromPacket : channelCount;

    for (int i = 0; i < parsedChannelCount; i++) {
      final baseIndex = 1 + i * bytesPerChannel;
      if (baseIndex >= bytes.length) break;
      double value;
      switch (format) {
        case DataFormat.int8:
          int v = bytes[baseIndex];
          if (v > 127) {v -= 256;}
          value = v.toDouble();
          break;
        case DataFormat.uint12Le:
          if (baseIndex + 1 >= bytes.length) {continue;}
          final low = bytes[baseIndex];
          final high = bytes[baseIndex + 1];
          final raw16 = (high << 8) | low;
          final raw12 = raw16 & 0x0FFF;
          value = raw12.toDouble();
          break;
      }
      channels.add(value);
    }
    return EegSample(timestamp: timestamp, channels: channels);
  }
}
