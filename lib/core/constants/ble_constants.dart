// BLE scan/connect timeouts; MTU; EEG service/characteristic UUIDs; device text commands
class BleConstants {
  BleConstants._();

  // scan/connect throttling and timeouts
  static const Duration scanTimeout = Duration(seconds: 5);
  static const Duration connectTimeout = Duration(seconds: 5);
  static const int requestMtuSize = 512;
  static const Duration minScanInterval = Duration(seconds: 3);
  static const Duration scanResultsCollectDelay = Duration(milliseconds: 800);
  static const int defaultSampleRateHz = 300; // default sample rate for EEG device
  static const List<String> skipServiceParts = [
    '180f', // Battery
    '180a', // Device Info
    '1800', // Generic Access
    '1801', // Generic Attribute
    '1805', // Current Time
  ];

  // EEG Device
  static const String eegServiceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String commandCharUuid = '0000fff2-0000-1000-8000-00805f9b34fb';
  static const String responseCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

  // Custom text commands for EEG device
  static const String cmdPing = 'ping;';
  static const String cmdStartTransmission = 'start;';
  static const String cmdStopTransmission = 'stop;';
  static const String cmdOff = 'off;';
  static String cmdSetSamplingRate(int hz) => 'rate $hz;'; // e.g. rate 300;
}
