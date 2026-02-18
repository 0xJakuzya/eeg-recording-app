import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/eeg_models.dart';
import 'package:ble_app/utils/extension.dart';

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

  /// For int24Be: packet can contain multiple samples (e.g. 100 bytes = 4 samples).
  /// Returns all samples from the packet. For other formats returns single-element list.
  List<EegSample> parseAllBytes(List<int> bytes) {
    if (format == DataFormat.int24Be) {
      return parseInt24BeAll(bytes);
    }
    return [parseBytes(bytes)];
  }

  /// int24Be, 8 channels: [packet_header 2b][sample0: 8ch×3][sample1: 24b][sample2...]
  /// 100 bytes = 2 + 4×24 = 98 → 4 samples. One header per packet, samples contiguous.
  List<EegSample> parseInt24BeAll(List<int> bytes) {
    const int packetHeaderBytes = 2;
    const int eegChannels = 8;
    const int bytesPerSample = eegChannels * 3; // 24
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
      // Format from EEG device: [marker, skip, ch0_hi, ch0_mid, ch0_lo, ...] — 26 bytes min
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
          final volts =
              signed * (RecordingConstants.adcVrefVolts / RecordingConstants.max24Bit);
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
          value =
              signed * (RecordingConstants.adcVrefVolts / RecordingConstants.max24Bit);
          break;
      }
      channels.add(value);
    }
    return EegSample(timestamp: timestamp, channels: channels);
  }
}
