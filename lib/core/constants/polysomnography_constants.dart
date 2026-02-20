/// Константы для интеграции с полисомнографическим сервисом анализа.
class PolysomnographyConstants {
  PolysomnographyConstants._();
  static const String defaultBaseUrl = 'http://192.168.0.173:8000'; // base url polysomnography service
  static const String saveUserFilePath = '/users/save_user_file'; 
  static const String getPatientFilesListPath = '/users/get_patient_files_list'; 
  static const String savePredictJsonPath = '/users/save_predict_json'; 
  static const String sleepGraphPath = '/users/sleep_graph'; 
  static const double defaultSamplingFrequencyHz = 100.0; // default sampling frequency for txt files (100Hz)
  static const String uploadFileFieldName = 'file'; 
  static const String preferredEdfChannel = 'C2A2'; 
}
