import 'package:ble_app/utils/extension.dart';

class PolysomnographyConstants {
  PolysomnographyConstants._();
  static const String defaultBaseUrl = 'http://192.168.0.173:8000';
  static const String saveUserFilePath = '/users/save_user_file';
  static const String getPatientFilesListPath = '/users/get_patient_files_list';
  static const String savePredictJsonPath = '/users/save_predict_json';
  static const String defaultChannel = 'C2A2';
  static const double defaultSamplingFrequencyHz = 100.0;
  static const DataFormat defaultEegDataFormat = DataFormat.eeg24BitVolt;
  static const bool useRawInt8ForGraph = true;
}