import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/core/common/eeg_sample.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

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

  List<EegSample> parseAllBytes(List<int> bytes) {
    if (format == DataFormat.int24Be) {
      return parseInt24BeAll(bytes);
    }
    return [parseBytes(bytes)];
  }

  List<EegSample> parseInt24BeAll(List<int> bytes) {
    const int packetHeaderBytes = 2;
    const int eegChannels = 8;
    const int bytesPerSample = eegChannels * 3;
    final samples = <EegSample>[];
    int offset = packetHeaderBytes;
    while (offset + bytesPerSample <= bytes.length) {
      final channels = <double>[];
      for (int i = 0; i < eegChannels; i++) {
        final base = offset + i * 3;
        final b0 = bytes[base];
        final b1 = bytes[base + 1];
        final b2 = bytes[base + 2];
        final raw24 = (b0 << 16) | (b1 << 8) | b2;
        final signed = raw24 > 0x7FFFFF ? raw24 - (1 << 24) : raw24;
        final volts = signed *
            (RecordingConstants.adcVrefVolts / RecordingConstants.max24Bit);
        channels.add(volts);
      }
      samples.add(EegSample(timestamp: DateTime.now(), channels: channels));
      offset += bytesPerSample;
    }
    return samples.isNotEmpty ? samples : [parseBytes(bytes)];
  }

  EegSample parseBytes(List<int> bytes) {
    final channels = <double>[];
    final timestamp = DateTime.now();

    if (format == DataFormat.int24Be) {
      const int headerBytes = 2;
      const int eegChannels = 8;
      const int minLen = headerBytes + eegChannels * 3;
      if (bytes.length >= minLen) {
        for (int i = 0; i < eegChannels; i++) {
          final baseIndex = headerBytes + i * 3;
          final b0 = bytes[baseIndex];
          final b1 = bytes[baseIndex + 1];
          final b2 = bytes[baseIndex + 2];
          final raw24 = (b0 << 16) | (b1 << 8) | b2;
          final signed = raw24 > 0x7FFFFF ? raw24 - (1 << 24) : raw24;
          final volts = signed *
              (RecordingConstants.adcVrefVolts / RecordingConstants.max24Bit);
          channels.add(volts);
        }
        return EegSample(timestamp: timestamp, channels: channels);
      }
    }

    final availableBytes = bytes.length - 1;
    final maxChannelsFromPacket = availableBytes ~/ bytesPerChannel;
    final parsedChannelCount = maxChannelsFromPacket < channelCount
        ? maxChannelsFromPacket
        : channelCount;

    for (int i = 0; i < parsedChannelCount; i++) {
      final baseIndex = 1 + i * bytesPerChannel;
      if (baseIndex >= bytes.length) break;
      double value;
      switch (format) {
        case DataFormat.int8:
          int v = bytes[baseIndex];
          if (v > 127) v -= 256;
          value = v.toDouble();
          break;
        case DataFormat.uint12Le:
          if (baseIndex + 1 >= bytes.length) continue;
          final low = bytes[baseIndex];
          final high = bytes[baseIndex + 1];
          final raw16 = (high << 8) | low;
          final raw12 = raw16 & 0x0FFF;
          value = raw12.toDouble();
          break;
        case DataFormat.int24Be:
          if (baseIndex + 2 >= bytes.length) continue;
          final b0 = bytes[baseIndex];
          final b1 = bytes[baseIndex + 1];
          final b2 = bytes[baseIndex + 2];
          final raw24 = (b0 << 16) | (b1 << 8) | b2;
          final signed = raw24 > 0x7FFFFF ? raw24 - (1 << 24) : raw24;
          value = signed *
              (RecordingConstants.adcVrefVolts /
                  RecordingConstants.max24Bit);
          break;
      }
      channels.add(value);
    }
    return EegSample(timestamp: timestamp, channels: channels);
  }
}
