/// ble constant values
/// scan timeouts, connection timeout, and scan throttling

class BleConstants {
  BleConstants._();
  static const Duration scanTimeout = Duration(seconds: 5); // scan timeout
  static const Duration connectTimeout = Duration(seconds: 5); // connect timeout
  static const Duration minScanInterval = Duration(seconds: 3); // min scan interval
  static const Duration scanResultsCollectDelay = Duration(milliseconds: 800); // scan results collect delay
}
