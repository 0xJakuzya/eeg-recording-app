import 'dart:typed_data';
import 'package:ble_app/utils/extension.dart';
import 'package:ble_app/models/eeg_models.dart';
import 'package:ble_app/core/polysomnography_constants.dart';

/// Service for parsing raw BLE bytes into EEG samples.
class EegParserService {
  EegParserService({
    this.channelCount = 1,
    this.format = PolysomnographyConstants.defaultEegDataFormat,
  });

  final int channelCount;
  final DataFormat format;

  /// Буфер для склейки BLE-пакетов (MTU ~20 байт, кадр 28 байт)
  final List<int> eeg24Buffer = [];

  int get bytesPerChannel => format.bytesPerChannel;
  int get expectedPacketSize => channelCount * bytesPerChannel;

  EegSample parseBytes(List<int> bytes) {
    final timestamp = DateTime.now();

    if (format == DataFormat.eeg24BitVolt) {
      eeg24Buffer.addAll(bytes);
      final samples = Eeg24BitVoltDecoder.decodeFromBuffer(eeg24Buffer);
      if (samples.isEmpty) {
        return EegSample(timestamp: timestamp, channels: const <double>[]);
      }
      final first = samples.first;
      return EegSample(
        timestamp: first.timestamp,
        channels: first.channelsVolts,
        rawChannels: first.rawChannelsInt8,
      );
    }

    final channels = <double>[];
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
          if (v > 127) {
            v -= 256;
          }
          value = v.toDouble();
          break;
        case DataFormat.eeg24BitVolt:
          // обработано выше
          value = 0.0;
          break;
      }
      channels.add(value);
    }
    return EegSample(timestamp: timestamp, channels: channels);
  }
}

class Eeg24BitVoltDecoder {
  static const double vRef = 1.2;
  static const int channelCount = 8;
  static const int frameSize = 26;
  static const int marker1 = 0x55;
  static const int marker2 = 0xAA;

  /// Парсит из буфера с учётом фрагментации BLE-пакетов. Удаляет распарсенные байты из [buffer].
  static List<EegVoltSample> decodeFromBuffer(List<int> buffer) {
    final now = DateTime.now();
    final List<EegVoltSample> result = [];
    int consumed = 0;

    while (buffer.length - consumed >= frameSize) {
      final data = buffer;
      final start = consumed;

      // Формат 1: 0x55 0xAA [26 байт]
      bool parsed = false;
      if (data.length - start >= 2 + frameSize &&
          data[start] == marker1 &&
          data[start + 1] == marker2) {
        parsed = parseFrame(data, start + 2, now, result);
        if (parsed) consumed = start + 2 + frameSize;
      }

      // Формат 2 (fallback): 26 байт без маркера [battery, 24 байта каналов]
      if (!parsed && data.length - start >= frameSize) {
        parsed = parseFrame(data, start, now, result);
        if (parsed) consumed = start + frameSize;
      }

      if (!parsed) break;
    }

    if (consumed > 0) {
      buffer.removeRange(0, consumed);
    }
    // защита от переполнения при потере синхронизации
    if (buffer.length > 512) {
      buffer.removeRange(0, buffer.length - 256);
    }
    return result;
  }

  static bool parseFrame(List<int> data, int offset, DateTime now, List<EegVoltSample> out) {
    if (offset + frameSize > data.length) return false;
    final battery = data[offset + 1];
    final List<double> channels = [];
    final List<double> rawInt8 = [];
    for (int ch = 0; ch < channelCount; ch++) {
      final i = offset + 2 + ch * 3;
      if (i + 2 >= data.length) break;
      int code = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2];
      if (code > (1 << 23)) code -= (1 << 24);
      channels.add(code * (vRef / (1 << 23)));
      rawInt8.add(code / (1 << 16)); // масштаб int8 (-128..127) для графика
    }
    if (channels.length == channelCount) {
      out.add(EegVoltSample(
        battery: battery,
        channelsVolts: channels,
        rawChannelsInt8: rawInt8,
        timestamp: now,
      ));
      return true;
    }
    return false;
  }

  static List<EegVoltSample> decodeNotification(Uint8List rawBytes) {
    final buffer = rawBytes.toList();
    return decodeFromBuffer(buffer);
  }

  static List<Uint8List> splitByMarker(
    Uint8List data,
    int marker1,
    int marker2,
  ) {
    final List<Uint8List> frames = [];
    int i = 0;
    while (i < data.length - 1) {
      if (data[i] == marker1 && data[i + 1] == marker2) {
        final start = i + 2;
        int j = start;
        while (j < data.length - 1 &&
            !(data[j] == marker1 && data[j + 1] == marker2)) {
          j++;
        }
        frames.add(Uint8List.sublistView(data, start, j));
        i = j;
      } else {
        i++;
      }
    }
    return frames;
  }
}

