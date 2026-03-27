// BLE scan/connect timeouts; MTU; EEG service/characteristic UUIDs; device text commands
class BleConstants {
  BleConstants._();

  // scan/connect throttling and timeouts
  static const Duration scanTimeout = Duration(seconds: 5);
  static const Duration connectTimeout = Duration(seconds: 5);
  static const int requestMtuSize = 240;
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

  // EEG device
  static const String eegHeadsetName = 'EEG Headset';
  static const String eegServiceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String commandCharUuid = '0000fff2-0000-1000-8000-00805f9b34fb';
  static const String responseCharUuid = '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String configCharUuid = '0000fff3-0000-1000-8000-00805f9b34fb';

  // Custom text commands for EEG Headset device (stored in constants)
  static const String cmdPing = 'ping;';
  static const String cmdStartTransmission = 'start;';
  static const String cmdStopTransmission = 'stop;';
  static const String cmdOff = 'off;';
  static const String cmdD100 = 'd100;';
  static const String cmdD250 = 'd250;';
  static const String cmdD500 = 'd500;';
  // sampling rate → BLE command mapping
  static const Map<int, String> sampleRateCommands = {
    100: cmdD100,
    250: cmdD250,
    500: cmdD500,
  };
  static const List<int> availableSampleRates = [100, 250, 500];
  static const int defaultRecordingSampleRateHz = 100;

  // retry: device sometimes ignores first commands
  static const int commandRetryAttempts = 3;
  static const Duration commandRetryDelay = Duration(milliseconds: 200);
}
