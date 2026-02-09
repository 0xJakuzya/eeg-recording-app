class BleConstants {
  BleConstants._();
  static const Duration scanTimeout = Duration(seconds: 5);
  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration minScanInterval = Duration(seconds: 3);
  static const Duration scanResultsCollectDelay = Duration(milliseconds: 800);
  static const int defaultSampleRateHz = 300;
}
