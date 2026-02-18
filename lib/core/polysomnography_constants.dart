/// Константы для интеграции с полисомнографическим сервисом анализа.
class PolysomnographyConstants {
  PolysomnographyConstants._();
  static const String defaultBaseUrl = 'http://192.168.0.173:8000';
  static const String saveUserFilePath = '/users/save_user_file'; //upload files
  static const String getPatientFilesListPath = '/users/get_patient_files_list';
  static const String savePredictJsonPath = '/users/save_predict_json'; // analysis and predict polysomnography
  static const String sleepGraphPath = '/users/sleep_graph'; // build plot
  static const String defaultChannel = 'N'; 
  static const double defaultSamplingFrequencyHz = 100.0;
  static const int modelRequiredSamplingHz = 100;

  /// Для TXT: только одноканальные данные.
  /// Для EDF: рекомендуется канал Fpz-Cz или аналогичная локализация.
  static const String preferredEdfChannel = 'Fpz-Cz';

  static const int defaultPatientId = 1;
  static String storageKey(String sessionId, int fileNumber) =>
      '${defaultPatientId}_${sessionId}_$fileNumber';
  static const bool predictUseQueryParams = true;
}


