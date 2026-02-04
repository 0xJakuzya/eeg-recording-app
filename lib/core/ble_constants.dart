/// BLE constant values
/// Scan timeouts, connection timeout, throttling and EEG device UUIDs.

class BleConstants {
  BleConstants._();
  static const Duration scanTimeout = Duration(seconds: 5); // scan timeout
  static const Duration connectTimeout = Duration(seconds: 5); // connect timeout
  static const Duration minScanInterval = Duration(seconds: 3); // min scan interval
  static const Duration scanResultsCollectDelay = Duration(milliseconds: 800); // scan results collect delay

  /// EEG device UUIDs 
  static const String eegServiceUuid = '2555a4bf-3b77-4603-9089-49db2ecba11a';
  static const String eegDataCharUuid = 'bc0bb800-5225-4a59-9668-7cc7c0c51821';
  static const String eegConfigServiceUuid = '00431c4a-a7a4-428b-a96d-d92d43c8c7cf';
  static const String eegConfigCharUuid = 'f1b41cde-dbf5-4acf-8679-ecb8b4dca6fe';

  /// Default EEG sampling frequency (Hz)
  static const int defaultSampleRateHz = 300;
}
