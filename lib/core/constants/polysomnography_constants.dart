/// Константы для интеграции с полисомнографическим сервисом анализа.
class PolysomnographyConstants {
  PolysomnographyConstants._();
  static const String defaultBaseUrl = 'http://192.168.0.173:8000';
  static const String saveUserFilePath = '/users/save_user_file';
  static const String getPatientFilesListPath = '/users/get_patient_files_list';
  static const String savePredictJsonPath = '/users/save_predict_json';
  static const String sleepGraphPath = '/users/sleep_graph';

  /// Частота дискретизации по умолчанию для .txt файлов (Гц).
  static const double defaultSamplingFrequencyHz = 100.0;

  /// Имя поля для загружаемого файла в FormData (если 422 — попробуйте 'upload').
  static const String uploadFileFieldName = 'file';

  /// Канал по умолчанию для EDF (совпадает с API).
  static const String preferredEdfChannel = 'C2A2';
}
