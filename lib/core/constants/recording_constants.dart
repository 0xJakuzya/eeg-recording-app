class RecordingConstants {
  RecordingConstants._();
  
  static const int realtimeBufferMaxSize = 5000;
  static const int csvBufferSize = 100;
  static const double sampleIntervalSeconds = 0.05;
  static const Duration durationTimerInterval = Duration(seconds: 1);
  static const Duration postStopDelay = Duration(seconds: 3);
  static const int demoDataPointCount = 200;
  static const int defaultRotationIntervalMinutes = 20; // default rotation interval for recording (20 minutes)
  
  static const String keyRecordingDirectory = 'recording_directory';
  static const String keyRotationIntervalMinutes = 'recording_rotation_minutes';
  static const String keyLastSessionNumber = 'last_session_number';
  static const String recordingFileExtension = '.txt';
  static const List<String> recordingFileExtensions = ['.txt', '.csv'];
  static const String keyLastSessionDate = 'last_session_date';
  static const String recordingFileExtension = '.txt'; // extension for recording in txt/csv
  static const String defaultRecordingBaseName = 'recording';
  
  static const int samplingRateMinHz = 100;
  static const int samplingRateMaxHz = 500;
  static const int samplingRateDefaultHz = 250;
  static const int samplingRateHz = samplingRateDefaultHz; // default sampling rate for recording
  
  static const double adcVrefVolts = 1.2; // reference voltage for 24-bit format (volts)
  static const int max24Bit = 1 << 23; 
  static const int csvWriteChannelCount = 1; // channels for recording in txt/csv
  static const String csvDelimiter = ' '; // delimiter for recording in txt/csv
  static const double eegScaleMicrovoltsPerMm = 7.0;
  static const double eegChartDisplayRangeVolts = eegScaleMicrovoltsPerMm * 10 * 1e-6; // 70 µV
  static const double eegSweepMmPerSec = 30.0;
  static const List<double> eegPaperWidthsMm = [150.0, 90.0, 300.0];
  static const int eegChartMaxDisplayPoints = 600;
}
