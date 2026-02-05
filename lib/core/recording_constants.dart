// recording and eeg constant values
// buffer sizes, sample format, timers, and demo data  
class RecordingConstants {
  RecordingConstants._();
  static const int realtimeBufferMaxSize = 200; // max buffer size
  static const int csvBufferSize = 100; // csv buffer
  static const int bytesPerChannel = 1; // bytes per channel (uint8 per channel)
  static const double sampleIntervalSeconds = 0.05; // sample interval
  static const Duration durationTimerInterval = Duration(seconds: 1); // timer interval
  static const Duration postStopDelay = Duration(seconds: 3); // stop delay
  static const int demoDataPointCount = 200; // demo data points
  static const String keyRecordingDirectory = 'recording_directory'; // recording directory key
  
  // bandpass filter for visualization
  static const double defaultBandpassLowHz = 10.0;  // high-pass cutoff
  static const double defaultBandpassHighHz = 120.0; // low-pass cutoff
  static const double emgDisplayRange = 60.0; // range of raw units shown fully
}
