import 'package:ble_app/core/polysomnography_constants.dart';

// model representing a single eeg data sample
// contains timestamp and voltage values for multiple channels.
// supports 1-8 channels with validation.
class EegSample {

  final DateTime timestamp;
  final List<double> channels;
  /// Сырые значения для графика (int8-масштаб). Если null — используется channels.
  final List<double>? rawChannels;

  EegSample({
    required this.timestamp,
    required this.channels,
    this.rawChannels,
  }) : assert(channels.length <= 8, 'EEG sample must have 0-8 channels');

  int get channelCount => channels.length;
  List<double> get channelsForDisplay {
    if (PolysomnographyConstants.useRawInt8ForGraph && rawChannels != null) {
      return rawChannels!;
    }
    return channels;
  }

  String toCsvLine() {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return '$timestampMs,${channels.join(',')}'; 
  }

  factory EegSample.fromCsvLine(String line) {
    final parts = line.split(','); 
    return EegSample(
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])), 
      channels: parts.sublist(1).map((e) => double.parse(e)).toList());
  }
  @override
  String toString() => 'EegSample(timestamp: $timestamp, channels: ${channels.length})';
}

class EegVoltSample {
  final int battery;
  final List<double> channelsVolts; // длина 8
  final List<double> rawChannelsInt8; // сырые 24-бит в масштабе int8 (-128..127)
  final DateTime timestamp;

  EegVoltSample({
    required this.battery,
    required this.channelsVolts,
    required this.rawChannelsInt8,
    required this.timestamp,
  }) : assert(channelsVolts.length == 8, 'EegVoltSample must contain exactly 8 channels');
}
