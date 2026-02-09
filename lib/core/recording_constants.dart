class RecordingConstants {
  RecordingConstants._();
  static const int realtimeBufferMaxSize = 200; 
  static const int csvBufferSize = 100; 
  static const double sampleIntervalSeconds = 0.05; 
  static const Duration durationTimerInterval = Duration(seconds: 1); 
  static const Duration postStopDelay = Duration(seconds: 3); 
  static const int demoDataPointCount = 200; 
  static const String keyRecordingDirectory = 'recording_directory'; 
}
