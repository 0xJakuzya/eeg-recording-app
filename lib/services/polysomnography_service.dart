import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:ble_app/core/polysomnography_constants.dart';

class PredictResult {
  const PredictResult({
    required this.prediction,
    required this.jsonIndex,
  });

  final Map<String, dynamic>? prediction;
  final int? jsonIndex;
}

/// Информация о файле пациента из API.
class PatientFileInfo {
  const PatientFileInfo({
    required this.index,
    required this.name,
    this.extra,
  });

  final int index;
  final String name;
  final Map<String, dynamic>? extra;

  bool get isEdf => name.toLowerCase().endsWith('.edf');
}

/// API-клиент для взаимодействия с полисомнографическим сервисом.
class PolysomnographyApiService {
  PolysomnographyApiService({
    String? baseUrl,
    String Function()? baseUrlGetter,
    this.apiKey,
  })  : _baseUrl = baseUrl ?? PolysomnographyConstants.defaultBaseUrl,
        _baseUrlGetter = baseUrlGetter;

  final String _baseUrl;
  final String Function()? _baseUrlGetter;

  String get baseUrl => _baseUrlGetter != null ? _baseUrlGetter!() : _baseUrl;

  final String? apiKey;

  void applyAuthHeader(http.BaseRequest request) {
    if (apiKey != null) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  static String _parseErrorBody(String body, int statusCode) {
    if (body.isEmpty) return 'Код $statusCode';
    try {
      final d = jsonDecode(body);
      if (d is Map) {
        final detail = d['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final msgs = detail.map((e) {
            if (e is Map) {
              final loc = e['loc'];
              final msg = e['msg'] ?? '';
              if (loc is List && loc.isNotEmpty) {
                final field = loc.last.toString();
                return '$field: $msg';
              }
              return msg.toString();
            }
            return e.toString();
          }).toList();
          return msgs.join('; ');
        }
        if (d['error'] != null) return d['error'].toString();
      }
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  Map<String, String> get _headers {
    if (apiKey != null) {
      return {'Authorization': 'Bearer $apiKey'};
    }
    return {};
  }

  /// Загрузка одного TXT/EDF файла на сервер.
  /// Query: patient_id, patient_name, sampling_frequency (для .txt).
  /// Body: multipart/form-data с полем file.
  Future<Map<String, dynamic>> uploadPatientFile({
    required File file,
    required int patientId,
    required String patientName,
    double? samplingFrequency,
  }) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final isEdf = filename.toLowerCase().endsWith('.edf');

    final queryParams = <String, String>{
      'patient_id': patientId.toString(),
      'patient_name': patientName,
    };
    if (!isEdf) {
      queryParams['sampling_frequency'] =
          (samplingFrequency ?? PolysomnographyConstants.defaultSamplingFrequencyHz)
              .toInt()
              .toString();
    }

    final formData = FormData.fromMap({
      PolysomnographyConstants.uploadFileFieldName: await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: apiKey != null ? {'Authorization': 'Bearer $apiKey'} : null,
    ));

    try {
      final response = await dio.post(
        PolysomnographyConstants.saveUserFilePath,
        data: formData,
        queryParameters: queryParams,
      );

      if (response.statusCode != 200) {
        final msg = _parseErrorBody(
          response.data?.toString() ?? '',
          response.statusCode ?? 0,
        );
        throw Exception('Ошибка загрузки ${response.statusCode}: $msg');
      }

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      if (response.data != null) {
        final decoded = jsonDecode(response.data.toString());
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return <String, dynamic>{'result': response.data?.toString() ?? ''};
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final data = e.response?.data;
      final bodyStr = data is Map ? jsonEncode(data) : (data?.toString() ?? e.message ?? '');
      final msg = _parseErrorBody(bodyStr, statusCode);
      throw Exception('Ошибка загрузки $statusCode: $msg');
    }
  }

  /// Получить список файлов пациента по ID.
  Future<List<PatientFileInfo>> getPatientFilesList(int patientId) async {
    final uri = Uri.parse(
      '$baseUrl${PolysomnographyConstants.getPatientFilesListPath}',
    ).replace(queryParameters: {'patient_id': patientId.toString()});

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      String error = 'Ошибка ${response.statusCode}';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] != null) {
          error = err['error'].toString();
        }
      } catch (ignored) {}
      throw Exception(error);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return [];
    }

    final result = <PatientFileInfo>[];

    final filesList = decoded['files_list'];
    if (filesList is List) {
      for (var i = 0; i < filesList.length; i++) {
        final item = filesList[i];
        String name = 'file_$i';
        if (item is String) {
          name = item.split(Platform.pathSeparator).last;
          if (name.isEmpty) name = item.split('/').last;
        } else if (item is Map) {
          name = (item['name'] ?? item['filename'] ?? name).toString();
        }
        result.add(PatientFileInfo(
          index: i,
          name: name,
          extra: item is Map ? Map<String, dynamic>.from(item) : null,
        ));
      }
      return result;
    }

    for (final entry in decoded.entries) {
      final index = int.tryParse(entry.key);
      if (index == null) continue;
      final value = entry.value;
      String name = 'file_$index';
      if (value is String) {
        final parts = value.split(RegExp(r'[/\\]'));
        name = parts.isNotEmpty ? parts.last : value;
        if (name.isEmpty) name = value;
      }
      result.add(PatientFileInfo(index: index, name: name));
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  /// Сохранить файл для визуализации (JSON) и получить предикт.
  /// file_index — индекс из списка файлов пациента (get_patient_files_list).
  Future<PredictResult> savePredictJson({
    required int patientId,
    required int fileIndex,
    String? channel,
  }) async {
    final queryParams = <String, String>{
      'patient_id': patientId.toString(),
      'file_index': fileIndex.toString(),
    };
    if (channel != null && channel.isNotEmpty) {
      queryParams['channel'] = channel;
    }

    final uri = Uri.parse('$baseUrl${PolysomnographyConstants.savePredictJsonPath}')
        .replace(queryParameters: queryParams);

    final request = http.Request('POST', uri);
    applyAuthHeader(request);

    final client = http.Client();
    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    client.close();

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] != null) {
          detail = err['error'].toString();
        }
      } catch (ignored) {}
      throw Exception('Ошибка предикта ${response.statusCode}: $detail');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    int? jsonIndex;
    Map<String, dynamic>? prediction;

    void extractFrom(Map<String, dynamic> m) {
      if (jsonIndex == null) {
        for (final key in ['index', 'json_index', 'file_index', 'id']) {
          final v = int.tryParse(m[key]?.toString() ?? '');
          if (v != null) {
            jsonIndex = v;
            break;
          }
        }
      }
      if (prediction == null && m['prediction'] is Map) {
        prediction = Map<String, dynamic>.from(m['prediction'] as Map);
      }
    }

    extractFrom(decoded);
    final result = decoded['result'];
    if (result is Map) {
      extractFrom(Map<String, dynamic>.from(result));
    }

    return PredictResult(prediction: prediction, jsonIndex: jsonIndex);
  }

  /// Загрузка PNG-гипнограммы с сервера.
  Future<List<int>> fetchSleepGraphImage(
    int index, {
    int? startFrom,
    int? endTo,
  }) async {
    final params = <String, String>{'index': index.toString()};
    if (startFrom != null) params['start_from'] = startFrom.toString();
    if (endTo != null) params['end_to'] = endTo.toString();

    final uri = Uri.parse(
      '$baseUrl${PolysomnographyConstants.sleepGraphPath}',
    ).replace(queryParameters: params);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки гипнограммы: ${response.statusCode} ${response.body}',
      );
    }
    return response.bodyBytes;
  }
}
