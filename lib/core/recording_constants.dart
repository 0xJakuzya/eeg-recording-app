/// recording and eeg constant values
/// buffer sizes, sample format, timers, and demo data

class RecordingConstants {
  RecordingConstants._();
  static const int realtimeBufferMaxSize = 200; // max buffer size
  static const int csvBufferSize = 100; // csv buffer
  static const int bytesPerChannel = 2; // bytes per channel
  static const double sampleIntervalSeconds = 0.05; // sample interval
  static const Duration durationTimerInterval = Duration(seconds: 1); // timer interval
  static const Duration postStopDelay = Duration(seconds: 3); // stop delay
  static const int demoDataPointCount = 200; // demo data points
  static const List<int> channelOptions = [1, 2, 4, 8]; // channel options
}
