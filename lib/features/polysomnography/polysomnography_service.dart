import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:ble_app/core/constants/polysomnography_constants.dart';

// api response from save_predict_json; prediction map and index for hypnogram
class PredictResult {
  const PredictResult({
    required this.prediction,
    required this.jsonIndex,
  });

  final Map<String, dynamic>? prediction;
  final int? jsonIndex;
}

// file metadata from get_patient_files_list
class PatientFileInfo {
  const PatientFileInfo({
    required this.index,
    required this.name,
    this.extra,
  });

  final int index;
  final String name;
  final Map<String, dynamic>? extra;

  // true for .edf; affects channel param in save_predict_json
  bool get isEdf => name.toLowerCase().endsWith('.edf');
}

// upload files, get list, save_predict_json, fetch hypnogram image
class PolysomnographyApiService {
  PolysomnographyApiService({
    String? baseUrl,
    String Function()? baseUrlGetter,
    this.apiKey,
  })  : baseUrlStorage = baseUrl ?? PolysomnographyConstants.defaultBaseUrl,
        baseUrlGetterStorage = baseUrlGetter;

  final String baseUrlStorage;
  final String Function()? baseUrlGetterStorage;

  // baseUrlGetter preferred when set; else baseUrlStorage
  String get baseUrl =>
      baseUrlGetterStorage != null ? baseUrlGetterStorage!() : baseUrlStorage;

  final String? apiKey;

  // adds bearer token to request headers when apiKey set
  void applyAuthHeader(http.BaseRequest request) {
    if (apiKey != null) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  // empty map or bearer header for http requests
  Map<String, String> get authHeaders {
    if (apiKey != null) {
      return {'Authorization': 'Bearer $apiKey'};
    }
    return {};
  }

  // extract detail/msg from json error body; fallback to status code or raw body
  static String parseErrorBody(String body, int statusCode) {
    if (body.isEmpty) return 'Код $statusCode';
    try {
      final d = jsonDecode(body);
      if (d is! Map) return body.length > 200 ? '${body.substring(0, 200)}...' : body;
      final detail = d['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) return parseValidationErrors(detail);
      if (d['error'] != null) return d['error'].toString();
    } catch (ignored) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  // map validation error items to "field: msg" format
  static String parseValidationErrors(List detail) {
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

  // multipart upload; edf skips sampling_frequency param
  Future<Map<String, dynamic>> uploadPatientFile({
    required File file,
    required int patientId,
    required String patientName,
    double? samplingFrequency,
  }) async {
    final filename = file.path.split(Platform.pathSeparator).last;
    final isEdf = filename.toLowerCase().endsWith('.edf');

    final queryParams = buildUploadQueryParams(
      patientId: patientId,
      patientName: patientName,
      isEdf: isEdf,
      samplingFrequency: samplingFrequency,
    );

    final formData = FormData.fromMap({
      PolysomnographyConstants.uploadFileFieldName:
          await MultipartFile.fromFile(
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
        final msg = parseErrorBody(
          response.data?.toString() ?? '',
          response.statusCode ?? 0,
        );
        throw Exception('Ошибка загрузки ${response.statusCode}: $msg');
      }

      return parseUploadResponse(response.data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 0;
      final bodyStr = dioExceptionToBodyString(e);
      final msg = parseErrorBody(bodyStr, statusCode);
      throw Exception('Ошибка загрузки $statusCode: $msg');
    }
  }

  // patient_id, patient_name; sampling_frequency only for non-edf
  Map<String, String> buildUploadQueryParams({
    required int patientId,
    required String patientName,
    required bool isEdf,
    double? samplingFrequency,
  }) {
    final params = <String, String>{
      'patient_id': patientId.toString(),
      'patient_name': patientName,
    };
    if (!isEdf) {
      params['sampling_frequency'] = (samplingFrequency ??
              PolysomnographyConstants.defaultSamplingFrequencyHz)
          .toInt()
          .toString();
    }
    return params;
  }

  // accepts map or json string; fallback to result wrapper
  Map<String, dynamic> parseUploadResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data != null) {
      final decoded = jsonDecode(data.toString());
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return <String, dynamic>{'result': data?.toString() ?? ''};
  }

  // extracts body as string for parseErrorBody
  String dioExceptionToBodyString(DioException e) {
    final data = e.response?.data;
    if (data is Map) return jsonEncode(data);
    return data?.toString() ?? e.message ?? '';
  }

  // gets files list; supports array or map response format
  Future<List<PatientFileInfo>> getPatientFilesList(int patientId) async {
    final uri = Uri.parse(
      '$baseUrl${PolysomnographyConstants.getPatientFilesListPath}',
    ).replace(queryParameters: {'patient_id': patientId.toString()});

    final response = await http.get(uri, headers: authHeaders);

    if (response.statusCode != 200) {
      throw Exception(parseListError(response.body, response.statusCode));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return [];

    return parseFilesList(decoded);
  }

  // extracts error key from json; fallback to status
  String parseListError(String body, int statusCode) {
    try {
      final err = jsonDecode(body);
      if (err is Map && err['error'] != null) {
        return err['error'].toString();
      }
    } catch (ignored) {}
    return 'Ошибка $statusCode';
  }

  // dispatches to array or map parser by response shape
  List<PatientFileInfo> parseFilesList(Map<String, dynamic> decoded) {
    final filesList = decoded['files_list'];
    if (filesList is List) {
      return parseFilesListFromArray(filesList);
    }
    return parseFilesListFromMap(decoded);
  }

  // index from position; name from item or file_N fallback
  List<PatientFileInfo> parseFilesListFromArray(List filesList) {
    final result = <PatientFileInfo>[];
    for (var i = 0; i < filesList.length; i++) {
      final item = filesList[i];
      final name = extractFileNameFromItem(item, 'file_$i');
      result.add(PatientFileInfo(
        index: i,
        name: name,
        extra: item is Map ? Map<String, dynamic>.from(item) : null,
      ));
    }
    return result;
  }

  // string path: last segment; map: name/filename key; else fallback
  String extractFileNameFromItem(dynamic item, String fallback) {
    if (item is String) {
      final name = item.split(Platform.pathSeparator).last;
      return name.isNotEmpty ? name : item.split('/').last;
    }
    if (item is Map) {
      return (item['name'] ?? item['filename'] ?? fallback).toString();
    }
    return fallback;
  }

  // keys as index; values as path or name; sorted by index
  List<PatientFileInfo> parseFilesListFromMap(Map<String, dynamic> decoded) {
    final result = <PatientFileInfo>[];
    for (final entry in decoded.entries) {
      final index = int.tryParse(entry.key);
      if (index == null) continue;
      final value = entry.value;
      final name = value is String ? fileNameFromPath(value) : 'file_$index';
      result.add(PatientFileInfo(index: index, name: name));
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  // last path segment; handles / and backslash
  String fileNameFromPath(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    final name = parts.isNotEmpty ? parts.last : path;
    return name.isEmpty ? path : name;
  }

  // POST save_predict_json; returns prediction and json index for hypnogram
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

    final uri = Uri.parse(
        '$baseUrl${PolysomnographyConstants.savePredictJsonPath}')
        .replace(queryParameters: queryParams);

    final request = http.Request('POST', uri);
    applyAuthHeader(request);

    final client = http.Client();
    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    client.close();

    if (response.statusCode != 200) {
      throw Exception(parsePredictError(response.body, response.statusCode));
    }

    return parsePredictResponse(response.body);
  }

  // error key or full body; truncates long body
  String parsePredictError(String body, int statusCode) {
    try {
      final err = jsonDecode(body);
      if (err is Map && err['error'] != null) {
        return 'Ошибка предикта $statusCode: ${err['error']}';
      }
    } catch (ignored) {}
    return 'Ошибка предикта $statusCode: $body';
  }

  // double-json decode if string; extracts from root and result; fallback to root stage keys
  PredictResult parsePredictResponse(String body) {
    dynamic decoded = jsonDecode(body);
    if (decoded is String) decoded = jsonDecode(decoded);

    if (decoded is! Map) {
      throw Exception('Некорректный ответ сервера');
    }
    final decodedMap = Map<String, dynamic>.from(decoded as Map);

    final extracted = extractFromMap(decodedMap);
    int? jsonIndex = extracted.$1;
    Map<String, dynamic>? prediction = extracted.$2;

    final result = decodedMap['result'];
    if (result is Map) {
      final fromResult = extractFromMap(Map<String, dynamic>.from(result));
      jsonIndex ??= fromResult.$1;
      prediction ??= fromResult.$2;
    }

    if (prediction == null && decodedMap.isNotEmpty) {
      prediction = tryExtractPredictionFromRoot(decodedMap);
    }

    return PredictResult(prediction: prediction, jsonIndex: jsonIndex);
  }

  // extracts json_index and prediction map from response object
  static (int?, Map<String, dynamic>?) extractFromMap(Map<String, dynamic> m) {
    int? jsonIndex;
    for (final key in ['index', 'json_index', 'file_index', 'id']) {
      final v = int.tryParse(m[key]?.toString() ?? '');
      if (v != null) {
        jsonIndex = v;
        break;
      }
    }
    Map<String, dynamic>? prediction;
    if (m['prediction'] is Map) {
      prediction = Map<String, dynamic>.from(m['prediction'] as Map);
    } else if (m['result'] is Map) {
      final res = m['result'] as Map;
      if (res['prediction'] is Map) {
        prediction = Map<String, dynamic>.from(res['prediction'] as Map);
      }
    }
    return (jsonIndex, prediction);
  }

  // fallback: root may be prediction (wake, n1..rem with interval lists)
  Map<String, dynamic>? tryExtractPredictionFromRoot(
      Map<String, dynamic> decodedMap) {
    const knownStages = ['w', 'wake', 'n1', 'n2', 'n3', 'rem'];
    final hasStageKeys = decodedMap.keys.any(
        (k) => knownStages.contains(k.toString().toLowerCase()));
    return hasStageKeys ? Map<String, dynamic>.from(decodedMap) : null;
  }

  // pings url; returns null on success, error text otherwise (5s timeout)
  Future<String?> checkConnection(String url) async {
    final base = url.trim();
    if (base.isEmpty) return 'Укажите адрес сервера';

    final normalized = normalizeConnectionUrl(base);

    try {
      final uri = Uri.parse(normalized);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Превышено время ожидания (5 сек)'),
      );
      if (response.statusCode >= 200 && response.statusCode < 500) {
        return null;
      }
      return 'Сервер ответил: ${response.statusCode}';
    } catch (e) {
      return connectionErrorToMessage(e.toString());
    }
  }

  // add http prefix if missing; strip trailing slash
  String normalizeConnectionUrl(String base) {
    String url = base;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  // convert socket/timeout errors to user-friendly messages
  String connectionErrorToMessage(String msg) {
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Сервер недоступен. Проверьте:\n'
          '• Телефон и ПК в одной Wi‑Fi\n'
          '• IP и порт (например :8000)\n'
          '• Firewall на ПК\n'
          '• Docker: docker run -p 8000:8000 ...';
    }
    if (msg.contains('timeout') || msg.contains('Превышено')) {
      return 'Таймаут. Сервер не отвечает за 5 сек.';
    }
    return msg.length > 80 ? '${msg.substring(0, 80)}...' : msg;
  }

  // returns raw bytes; optional startFrom/endTo for range
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

    final response = await http.get(uri, headers: authHeaders);

    if (response.statusCode != 200) {
      throw Exception(
        'Ошибка загрузки гипнограммы: ${response.statusCode} ${response.body}',
      );
    }
    return response.bodyBytes;
  }
}
