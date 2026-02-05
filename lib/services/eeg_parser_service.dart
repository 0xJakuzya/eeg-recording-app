import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/eeg_sample.dart';

// Service for parsing raw BLE bytes into EEG samples.
// Device protocol: 1 byte counter + 1 byte per channel (signed int8).
// Supports configurable channel count (1–8 channels).
class EegParserService {
  
  final int channelCount; // eeg channels to parse
  EegParserService({this.channelCount = 1}); // default 1 channel
  int get expectedPacketSize => channelCount * RecordingConstants.bytesPerChannel; 

  // parse raw bytes into eeg sample
  EegSample parseBytes(List<int> bytes) {

    final channels = <double>[]; // list of channels
    final timestamp = DateTime.now(); // current timestamp
    
    // first byte is packet counter, skip it
    final availableBytes = bytes.length - 1;
    final maxChannelsFromPacket = availableBytes ~/ RecordingConstants.bytesPerChannel;
    final parsedChannelCount = maxChannelsFromPacket < channelCount
        ? maxChannelsFromPacket
        : channelCount;
    
    // parse channels
    for (int i = 0; i < parsedChannelCount; i++) {
      final byteIndex = 1 + i * RecordingConstants.bytesPerChannel;
      int value = bytes[byteIndex];

      // convert unsigned byte to signed int8 (-128..127)
      if (value > 127) {
        value -= 256;
      }
      final scaledValue = value.toDouble();
      channels.add(scaledValue);
    }
    // return eeg sample with timestamp and channels
    return EegSample(timestamp: timestamp, channels: channels); 
  }
}
