import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ble_app/core/polysomnography_constants.dart';

class PredictResult {
  const PredictResult({
    required this.prediction,
    required this.jsonIndex,
  });

  final Map<String, dynamic>? prediction;
  final int? jsonIndex;
}

/// API-клиент для взаимодействия с полисомнографическим сервисом.
///
/// Поддерживает:
/// - загрузку TXT/EDF файлов (POST /users/save_user_file)
/// - запрос анализа и предикта (POST /users/save_predict_json)
/// - получение гипнограммы PNG (GET /users/sleep_graph)
class PolysomnographyApiService {
  PolysomnographyApiService({
    String? baseUrl,
    this.apiKey,
  }) : baseUrl = baseUrl ?? PolysomnographyConstants.defaultBaseUrl;

  final String baseUrl;
  final String? apiKey;

  void applyAuthHeader(http.BaseRequest request) {
    if (apiKey != null) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  /// Загрузка одного TXT/EDF файла на сервер.
  ///
  /// [patientName] — ключ хранения (например, `1_session_1_1`).
  /// Возвращает список имён загруженных файлов из ответа сервера.
  Future<List<String>> uploadTxtFile({
    required File file,
    required int patientId,
    required String patientName,
    required double samplingFrequency,
  }) async {
    final uri = Uri.parse('$baseUrl${PolysomnographyConstants.saveUserFilePath}')
        .replace(queryParameters: <String, String>{
      'patient_id': patientId.toString(),
      'patient_name': patientName,
      'sampling_frequency': samplingFrequency.toString(),
    });

    final request = http.MultipartRequest('POST', uri);
    applyAuthHeader(request);

    final filename = file.path.split(Platform.pathSeparator).last;
    final isEdf = filename.toLowerCase().endsWith('.edf');
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
        contentType: isEdf
            ? MediaType('application', 'octet-stream')
            : MediaType('text', 'plain'),
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
    } catch (ignored) {}
    return <String>[filename];
  }

  /// Загрузка всех файлов сессии на сервер.
  ///
  /// [sessionId] — идентификатор сессии (например, `session_1`).
  /// [patientId] — ID пациента (по умолчанию из констант).
  Future<void> uploadSessionFiles({
    required List<File> files,
    required String sessionId,
    int? patientId,
  }) async {
    final pid = patientId ?? PolysomnographyConstants.defaultPatientId;
    final samplingFreq =
        PolysomnographyConstants.defaultSamplingFrequencyHz;

    for (var i = 0; i < files.length; i++) {
      final storageKey =
          PolysomnographyConstants.storageKey(sessionId, i + 1);
      await uploadTxtFile(
        file: files[i],
        patientId: pid,
        patientName: storageKey,
        samplingFrequency: samplingFreq,
      );
    }
  }

  /// Запрос анализа и предикта стадий сна.
  ///
  /// [sessionId] — идентификатор сессии.
  /// [fileIndex] — индекс файла (0-based), по которому делается предикт.
  /// [isEdf] — true, если используется EDF-файл (добавляется channel в запрос).
  Future<PredictResult> requestPredict({
    required String sessionId,
    required int fileIndex,
    bool isEdf = false,
    int? patientId,
  }) async {
    final pid = patientId ?? PolysomnographyConstants.defaultPatientId;
    final predictStorageKey =
        PolysomnographyConstants.storageKey(sessionId, fileIndex + 1);
    final predictBase =
        '$baseUrl${PolysomnographyConstants.savePredictJsonPath}';

    http.Response predictResponse;

    if (PolysomnographyConstants.predictUseQueryParams) {
      var predictUri = Uri.parse(predictBase).replace(queryParameters: {
        'patient_id': pid.toString(),
        'patient_name': predictStorageKey,
        'file_index': fileIndex.toString(),
      });
      if (isEdf) {
        predictUri = predictUri.replace(
          queryParameters: {
            ...predictUri.queryParameters,
            'channel': PolysomnographyConstants.preferredEdfChannel,
          },
        );
      }
      predictResponse = await http.post(predictUri);
    } else {
      final predictBody = <String, dynamic>{
        'patient_id': pid,
        'patient_name': predictStorageKey,
        'file_index': fileIndex,
      };
      if (isEdf) {
        predictBody['channel'] =
            PolysomnographyConstants.preferredEdfChannel;
      }
      predictResponse = await http.post(
        Uri.parse(predictBase),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(predictBody),
      );
    }

    if (predictResponse.statusCode != 200) {
      String detail = predictResponse.body;
      try {
        final err = jsonDecode(predictResponse.body);
        if (err is Map && err['detail'] != null) {
          detail = err['detail'].toString();
        }
      } catch (ignored) {}
      throw Exception('Ошибка предикта ${predictResponse.statusCode}: $detail');
    }

    final decoded = jsonDecode(predictResponse.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    int? jsonIndex;
    for (final key in ['index', 'json_index', 'file_index', 'id']) {
      if (decoded[key] != null) {
        jsonIndex = int.tryParse(decoded[key].toString());
        if (jsonIndex != null) break;
      }
    }

    Map<String, dynamic>? prediction;
    if (decoded['prediction'] is Map) {
      prediction = Map<String, dynamic>.from(decoded['prediction'] as Map);
    }

    return PredictResult(prediction: prediction, jsonIndex: jsonIndex);
  }

  /// Загрузка PNG-гипнограммы с сервера.
  ///
  /// [index] — индекс сохранённого JSON (0-based для sleep_graph).
  /// Возвращает байты изображения или выбрасывает исключение при ошибке.
  Future<List<int>> fetchSleepGraphImage(int index) async {
    final uri = Uri.parse(
            '$baseUrl${PolysomnographyConstants.sleepGraphPath}')
        .replace(
      queryParameters: <String, String>{'index': index.toString()},
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
          'Ошибка загрузки гипнограммы: ${response.statusCode} ${response.body}',
      );
    }

    return response.bodyBytes;
  }
}
