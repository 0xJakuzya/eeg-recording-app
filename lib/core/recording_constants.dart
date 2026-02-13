class RecordingConstants {
  RecordingConstants._();

  /// Буфер графика: ~10 с при 250 Гц
  static const int realtimeBufferMaxSize = 2500; 
  static const int csvBufferSize = 100; 
  static const double sampleIntervalSeconds = 0.05; 
  static const Duration durationTimerInterval = Duration(seconds: 1); 
  static const Duration postStopDelay = Duration(seconds: 3); 
  static const int demoDataPointCount = 200; 
  static const int defaultRotationIntervalMinutes = 20;
  
  static const String keyRecordingDirectory = 'recording_directory'; 
  static const String keyRotationIntervalMinutes = 'recording_rotation_minutes';
  static const String keyLastSessionNumber = 'last_session_number';
  static const String keyLastSessionDate = 'last_session_date';
  static const String keyDataFormat = 'data_format';
  static const String keySamplingRateHz = 'device_sampling_rate_hz';
  static const String recordingFileExtension = '.csv';
  static const String defaultRecordingBaseName = 'recording';

  /// Supported sampling rates for EEG_Device (Hz)
  static const List<int> supportedSamplingRates = [50, 100, 250, 500, 1000];
  static const int defaultSamplingRateHz = 250;
}
