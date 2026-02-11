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
  // TODO: upload files and get predict
}