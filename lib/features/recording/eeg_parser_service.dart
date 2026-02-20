import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/core/common/eeg_sample.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

// parses raw ble bytes into eeg samples; int24be = 2-byte header + 8ch×3 bytes
class EegParserService {
  EegParserService({
    this.channelCount = 1,
    this.format = DataFormat.int24Be,
  });

  final int channelCount;
  final DataFormat format;
  int get bytesPerChannel => format.bytesPerChannel;
  int get expectedPacketSize => channelCount * bytesPerChannel;

  // int24be → parseInt24BeAll; else single-sample parseBytes
  List<EegSample> parseAllBytes(List<int> bytes) {
    if (format == DataFormat.int24Be) {
      return parseInt24BeAll(bytes);
    }
    return [parseBytes(bytes)];
  }

  // extract 8 channels as volts from bytes at offset; int24 be, adc ref
  List<double> parseInt24ChannelsAt(List<int> bytes, int offset) {
    const eegChannels = 8;
    const bytesPerSample = eegChannels * 3;
    if (offset + bytesPerSample > bytes.length) return [];
    final channels = <double>[];
    for (int i = 0; i < eegChannels; i++) {
      final base = offset + i * 3;
      final b0 = bytes[base];
      final b1 = bytes[base + 1];
      final b2 = bytes[base + 2];
      final raw24 = (b0 << 16) | (b1 << 8) | b2;
      final signed = raw24 > 0x7FFFFF ? raw24 - (1 << 24) : raw24;
      channels.add(signed *
          (RecordingConstants.adcVrefVolts / RecordingConstants.max24Bit));
    }
    return channels;
  }

  // multiple samples per packet; fallback to parseBytes if no complete samples
  List<EegSample> parseInt24BeAll(List<int> bytes) {
    const packetHeaderBytes = 2;
    const bytesPerSample = 8 * 3;
    final samples = <EegSample>[];
    int offset = packetHeaderBytes;
    while (offset + bytesPerSample <= bytes.length) {
      final channels = parseInt24ChannelsAt(bytes, offset);
      if (channels.isNotEmpty) {
        samples.add(EegSample(timestamp: DateTime.now(), channels: channels));
      }
      offset += bytesPerSample;
    }
    return samples.isNotEmpty ? samples : [parseBytes(bytes)];
  }

  // single sample; int24be with header, or generic channel extraction
  EegSample parseBytes(List<int> bytes) {
    final channels = <double>[];
    final timestamp = DateTime.now();

    if (format == DataFormat.int24Be) {
      const headerBytes = 2;
      const minLen = headerBytes + 8 * 3;
      if (bytes.length >= minLen) {
        final parsed = parseInt24ChannelsAt(bytes, headerBytes);
        if (parsed.isNotEmpty) {
          return EegSample(timestamp: timestamp, channels: parsed);
        }
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
