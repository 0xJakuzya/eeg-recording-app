// recording buffer sizes; timers; SharedPreferences keys; sampling; chart layout
// single-channel EEG device, 7-byte BLE packet, 120 Hz sampling
class RecordingConstants {
  RecordingConstants._();

  static const int realtimeBufferMaxSize = 5000;
  static const int csvBufferSize = 100;
  static const Duration durationTimerInterval = Duration(seconds: 1);
  static const Duration postStopDelay = Duration(seconds: 3);
  static const int demoDataPointCount = 200;
  static const int defaultRotationIntervalMinutes = 20;

  static const String keyRecordingDirectory = 'recording_directory';
  static const String keyRotationIntervalMinutes = 'recording_rotation_minutes';
  static const String keyLastSessionNumber = 'last_session_number';
  static const String recordingFileExtension = '.txt';
  static const List<String> recordingFileExtensions = ['.txt', '.csv'];
  // polysomnography format: saves as .txt, metadata header + one volts value per row
  static const String formatPolysomnography = 'polysomnography';
  static const Set<String> validFileFormats = {'.txt', '.csv', formatPolysomnography};
  static const String polysomnographyChannel = 'Channel';
  static const int polysomnographySamplingRateHz = 100;
  static const String keyLastSessionDate = 'last_session_date';
  static const String defaultRecordingBaseName = 'recording';

  // sampling: 120 Hz single-channel
  static const int samplingRateHz = 120;
  static const double sampleIntervalSeconds = 1.0 / samplingRateHz;

  // ADC reference voltage; int24 range ±8388608
  static const double adcVrefVolts = 1.2;

  // BLE packet: [0xAA] [Battery] [Seq] [D2] [D1] [D0] [0x55]
  static const int blePacketSize = 7;

  // signal quality: flat signal detection
  static const double eegFlatSignalVarianceThreshold = 1e-8;
  static const int eegValidationWindowSamples = 600; 

  // chart layout
  static const double eegChartDisplayRangeVolts = 1.0;
  static const double eegSweepMmPerSec = 30.0;
  static const List<double> eegPaperWidthsMm = [30.0, 60.0, 90.0, 150.0, 300.0];

  // adaptive LTTB downsampling: target density is 1 point per pixel
  static const double eegChartPointsPerPixel = 1.0;
  static const int eegChartMinDisplayPoints = 100;
  static const int eegChartMaxDisplayPoints = 600;

  static const bool applyFilterOnRecording = false;

  /// Print data flow to terminal: BLE → Parser → Buffer → CSV → Chart
  static const bool eegDataFlowDebug = true;
}
