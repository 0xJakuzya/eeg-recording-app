class RecordingConstants {
  RecordingConstants._();

  /// Samples to keep for real-time chart. At 250 Hz: 2500≈10 s; at 500 Hz: 5000≈10 s.
  static const int realtimeBufferMaxSize = 5000;
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

  static const List<int> supportedSamplingRates = [50, 100, 250, 500, 1000];
  /// Рекомендуется 100 Гц для совместимости с моделью анализа.
  static const int defaultSamplingRateHz = 100;

  /// ADC reference voltage for 24-bit format (volts). Formula: volts = raw * (Vref / 2^23)
  static const double adcVrefVolts = 1.2;
  static const int max24Bit = 1 << 23; // 8388608

  /// Число каналов в файле. Для модели анализа требуется 1 канал (TXT — одноканальный).
  static const int csvWriteChannelCount = 1;

  /// Разделитель в записи файла: пробел ' ', двоеточие ':', точка с запятой ';' и т.д.
  static const String csvDelimiter = ' ';


  /// Масштаб: 7 µV/мм. Для 10 мм размаха: 70 µV = 0.00007 В
  static const double eegScaleMicrovoltsPerMm = 7.0;
  static const double eegChartDisplayRangeVolts = eegScaleMicrovoltsPerMm * 10 * 1e-6; // 70 µV
  /// Развёртка: 30 мм/с (1 с = 30 мм по горизонтали)
  static const double eegSweepMmPerSec = 30.0;
  /// Ширина «страницы» в мм. При 30 мм/с: 90мм=3с, 150мм=5с, 300мм=10с.
  static const List<double> eegPaperWidthsMm = [150.0, 90.0, 300.0];

  /// Max points per channel for chart. At 500 Hz: 600 точек для плавной линии
  static const int eegChartMaxDisplayPoints = 600;
}
