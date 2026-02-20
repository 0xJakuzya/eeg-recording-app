// immutable sample: timestamp + channel voltages; 1-8 channels; CSV serialization for recording/replay
class EegSample {
  final DateTime timestamp;
  final List<double> channels;

  EegSample({
    required this.timestamp,
    required this.channels,
  }) : assert(
            channels.isNotEmpty && channels.length <= 8,
            'EEG sample must have 1-8 channels',
          ); // validation for parser/csv compatibility

  int get channelCount => channels.length;

  // format: millisecondsSinceEpoch,ch0,ch1,...
  String toCsvLine() {
    final timestampMs = timestamp.millisecondsSinceEpoch;
    return '$timestampMs,${channels.join(',')}';
  }

  // parse csv line: ms,ch0,ch1,...; used by CsvStreamService, file replay
  factory EegSample.fromCsvLine(String line) {
    final parts = line.split(',');
    return EegSample(
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])),
      channels: parts.sublist(1).map((e) => double.parse(e)).toList(),
    );
  }

  @override
  String toString() =>
      'EegSample(timestamp: $timestamp, channels: ${channels.length})';
}