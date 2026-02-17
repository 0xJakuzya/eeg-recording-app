/// Константы для интеграции с полисомнографическим сервисом анализа.
class PolysomnographyConstants {
  PolysomnographyConstants._();
  static const String defaultBaseUrl = 'http://192.168.0.173:8000';
  static const String saveUserFilePath = '/users/save_user_file';
  static const String getPatientFilesListPath = '/users/get_patient_files_list';
  static const String savePredictJsonPath = '/users/save_predict_json';
  /// Гипнограмма строится по JSON, сохранённому save_predict_json. index 0-based.
  /// GET /users/sleep_graph?index=N (&start_from, &end_to опционально)
  static const String sleepGraphPath = '/users/sleep_graph';
  static const String defaultChannel = 'N';
  static const double defaultSamplingFrequencyHz = 100.0;
  static const int modelRequiredSamplingHz = 100;
  /// Для TXT: только одноканальные данные.
  /// Для EDF: рекомендуется канал Fpz-Cz или аналогичная локализация.
  static const String preferredEdfChannel = 'Fpz-Cz';

  /// Фильтр подавления сетевой частоты 50 Гц должен быть применён к данным.

  /// Константные значения для загрузки и предикта (без запросов пользователю).
  static const int defaultPatientId = 1;
  /// Формат: 1_session_1_1, 1_session_1_2 — patientId_sessionId_fileNumber.
  static String storageKey(String sessionId, int fileNumber) =>
      '${defaultPatientId}_${sessionId}_$fileNumber';

  /// true = query params, false = JSON body для save_predict_json
  static const bool predictUseQueryParams = true;
}


