// constants for polysomnography analysis service integration
class PolysomnographyConstants {
  PolysomnographyConstants._();

  static const String defaultBaseUrl = 'http://192.168.0.173:8000'; // base URL when not configured
  static const String saveUserFilePath = '/users/save_user_file'; // upload EEG file
  static const String getPatientFilesListPath = '/users/get_patient_files_list'; // list patient sessions
  static const String savePredictJsonPath = '/users/save_predict_json'; // save prediction result
  static const String sleepGraphPath = '/users/sleep_graph'; // sleep stage graph endpoint
  static const double defaultSamplingFrequencyHz = 100.0; // for .txt files when not in CSV header
  static const String uploadFileFieldName = 'file'; // multipart form field name
  static const String preferredEdfChannel = 'C2A2'; // EEG channel for EDF export
}
