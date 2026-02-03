/// service for parsing raw ble bytes into eeg samples
/// converts binary data from bluetooth device into eeg sample objects.
/// supports configurable channel count (1-8 channels) with 2 bytes per channel.

import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/eeg_sample.dart';

class EegParserService {
  
  final int channelCount; // eeg channels to parse
  EegParserService({this.channelCount = 1}); // default to 1 channel
  int get expectedPacketSize => channelCount * RecordingConstants.bytesPerChannel; 

  // parse raw bytes into eeg sample
  EegSample parseBytes(List<int> bytes) {

    final channels = <double>[]; // list of channels
    final timestamp = DateTime.now(); // current timestamp

    for (int i = 0; i < channelCount; i++) {
      final byteIndex = i * RecordingConstants.bytesPerChannel;

      // combine two bytes into 16-bit signed integer 
      int value = bytes[byteIndex] | (bytes[byteIndex + 1] << 8);
      if (value > 32767) { value -= 65536; } // convert to signed integer
      final voltage = value.toDouble(); // convert to double voltage
      channels.add(voltage); // add to channels
    } 
    return EegSample(timestamp: timestamp, channels: channels); // return eeg sample with timestamp and channels
  }
}
