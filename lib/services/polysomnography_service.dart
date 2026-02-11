import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ble_app/core/polysomnography_constants.dart';

class PolysomnographyApiService {
  PolysomnographyApiService({
    String? baseUrl,
    this.apiKey,
  }) : baseUrl = baseUrl ?? PolysomnographyConstants.defaultBaseUrl;

  final String baseUrl;
  final String? apiKey;

  /// upload TXT/EDF files patient.
  Future<List<String>> uploadTxtFile({
    required File file,
    required int patientId,
    required String patientName,
    required double samplingFrequency,
  }) async {
    final uri = Uri.parse('$baseUrl${PolysomnographyConstants.saveUserFilePath}'
    ).replace(queryParameters: <String, String>{
      'patient_id': patientId.toString(),
      'patient_name': patientName,
      'sampling_frequency': samplingFrequency.toString(),
    });

    final request = http.MultipartRequest('POST', uri);

    if (apiKey != null) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }

    final filename = file.path.split(Platform.pathSeparator).last;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
        contentType: MediaType('text', 'plain'),
      ),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode} $body');
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['upload_files'];
        if (value is List) {
          return value.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return <String>[file.path.split(Platform.pathSeparator).last];
  }

  // get list files patient
  // GET /users/get_patient_files_list
  // return Map <fileIndex, filePath>.
  Future<Map<int, String>> getPatientFilesList(int patientId) async {
    final uri = Uri.parse(
            '$baseUrl${PolysomnographyConstants.getPatientFilesListPath}')
        .replace(
      queryParameters: <String, String>{
        'patient_id': patientId.toString(),
      },
    );

    final response = await http.get(uri, headers: <String, String>{
      if (apiKey != null) 'Authorization': 'Bearer $apiKey',
    });

    if (response.statusCode != 200) {
      throw Exception(
        'get_patient_files_list failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded.map<int, String>(
        (String key, dynamic value) =>
            MapEntry(int.parse(key), value.toString()),
      );
    }

    throw Exception(
      'Unexpected get_patient_files_list response: ${response.body}',
    );
  }

  // POST /users/save_predict_json for selected patient file.
  // return JSON-predict
  Future<Map<String, dynamic>> savePredictJson({
    required int patientId,
    required int fileIndex,
    String channel = PolysomnographyConstants.defaultChannel,
  }) async {
    final uri =
        Uri.parse('$baseUrl${PolysomnographyConstants.savePredictJsonPath}');

    final response = await http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(<String, dynamic>{
        'patient_id': patientId,
        'file_index': fileIndex,
        'channel': channel,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'save_predict_json failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception(
      'Unexpected save_predict_json response: ${response.body}',
    );
  }

  // pipeline: upload files and get predict.
  // steps:
  // 1. POST /users/save_user_file
  // 2. GET /users/get_patient_files_list
  // 3. POST /users/save_predict_json для последнего файла пациента.
  // return: (index, JSON-predict).
  Future<(int fileIndex, Map<String, dynamic> prediction)> uploadFileAndPredict({
    required File file,
    required int patientId,
    required String patientName,
    required double samplingFrequency,
    String channel = 'C2A2',
  }) async {
    // 1. upload files
    await uploadTxtFile(
      file: file,
      patientId: patientId,
      patientName: patientName,
      samplingFrequency: samplingFrequency,
    );
    // 2. get files index
    final files = await getPatientFilesList(patientId);
    if (files.isEmpty) {
      throw Exception('Нет файлов для пациента $patientId после загрузки');
    }
    final int lastIndex = files.keys.reduce(
      (int a, int b) => a > b ? a : b,
    );
    // 3. get predict files
    final prediction = await savePredictJson(
      patientId: patientId,
      fileIndex: lastIndex,
      channel: channel,
    );
    return (lastIndex, prediction);
  }
}