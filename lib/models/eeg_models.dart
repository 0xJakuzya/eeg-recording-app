// model representing a single eeg data sample
// contains timestamp and voltage values for multiple channels.
// supports 1-8 channels with validation.
class EegSample {

  final DateTime timestamp; 
  final List<double> channels;

  EegSample({
    required this.timestamp,
    required this.channels,
  }) : assert(channels.isNotEmpty && channels.length <= 8, 'EEG sample must have 1-8 channels');

  int get channelCount => channels.length; 

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
