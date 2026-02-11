class RecordingConstants {
  RecordingConstants._();

  static const int realtimeBufferMaxSize = 200; 
  static const int csvBufferSize = 100; 
  static const double sampleIntervalSeconds = 0.05; 
  static const Duration durationTimerInterval = Duration(seconds: 1); 
  static const Duration postStopDelay = Duration(seconds: 3); 
  static const int demoDataPointCount = 200; 
  static const int defaultRotationIntervalMinutes = 20;
  
  static const String keyRecordingDirectory = 'recording_directory'; 
  static const String keyRotationIntervalMinutes = 'recording_rotation_minutes';
  static const String keyLastSessionNumber = 'last_session_number';
  static const String recordingFileExtension = '.txt';
  static const String defaultRecordingBaseName = 'recording';
}
