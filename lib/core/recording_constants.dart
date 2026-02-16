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
  static const String recordingFileExtension = '.csv';
  static const String defaultRecordingBaseName = 'recording';

  static const List<int> supportedSamplingRates = [50, 100, 250, 500, 1000];
  static const int defaultSamplingRateHz = 250;

  /// ADC reference voltage for 24-bit format (volts). Formula: volts = raw * (Vref / 2^23)
  static const double adcVrefVolts = 1.2;
  static const int max24Bit = 1 << 23; // 8388608

  /// Number of channels to write to CSV (1–8). Edit to record 1, 2, etc. channels.
  static const int csvWriteChannelCount = 8;
}
