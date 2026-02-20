import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:ble_app/core/constants/polysomnography_constants.dart';

class PredictResult {
  const PredictResult({
    required this.prediction,
    required this.jsonIndex,
  });

  final Map<String, dynamic>? prediction;
  final int? jsonIndex;
}

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

/// API client for polysomnography service.
class PolysomnographyApiService {
  PolysomnographyApiService({
    String? baseUrl,
    String Function()? baseUrlGetter,
    this.apiKey,
  })  : baseUrlStorage = baseUrl ?? PolysomnographyConstants.defaultBaseUrl,
        baseUrlGetterStorage = baseUrlGetter;

  final String baseUrlStorage;
  final String Function()? baseUrlGetterStorage;

  String get baseUrl =>
      baseUrlGetterStorage != null ? baseUrlGetterStorage!() : baseUrlStorage;

  final String? apiKey;

  void applyAuthHeader(http.BaseRequest request) {
    if (apiKey != null) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
  }

  static String parseErrorBody(String body, int statusCode) {
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
    } catch (jsonParseError) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }

  Map<String, String> get authHeaders {
    if (apiKey != null) {
      return {'Authorization': 'Bearer $apiKey'};
    }
    return {};
  }

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
          (samplingFrequency ??
                  PolysomnographyConstants.defaultSamplingFrequencyHz)
              .toInt()
              .toString();
    }

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
      final bodyStr = data is Map
          ? jsonEncode(data)
          : (data?.toString() ?? e.message ?? '');
      final msg = parseErrorBody(bodyStr, statusCode);
      throw Exception('Ошибка загрузки $statusCode: $msg');
    }
  }

  Future<List<PatientFileInfo>> getPatientFilesList(int patientId) async {
    final uri = Uri.parse(
      '$baseUrl${PolysomnographyConstants.getPatientFilesListPath}',
    ).replace(queryParameters: {'patient_id': patientId.toString()});

    final response = await http.get(uri, headers: authHeaders);

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
      String detail = response.body;
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] != null) {
          detail = err['error'].toString();
        }
      } catch (ignored) {}
      throw Exception('Ошибка предикта ${response.statusCode}: $detail');
    }

    dynamic decoded = jsonDecode(response.body);

    // API может вернуть JSON-строку (schema "string") — парсим повторно
    if (decoded is String) {
      decoded = jsonDecode(decoded);
    }

    if (decoded is! Map) {
      throw Exception('Некорректный ответ сервера');
    }
    final decodedMap = Map<String, dynamic>.from(decoded as Map);

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
      if (prediction == null && m['result'] is Map) {
        final res = m['result'] as Map;
        if (res['prediction'] is Map) {
          prediction = Map<String, dynamic>.from(res['prediction'] as Map);
        }
      }
    }

    extractFrom(decodedMap);
    final result = decodedMap['result'];
    if (result is Map) {
      extractFrom(Map<String, dynamic>.from(result));
    }

    // Если prediction не найден — возможно, корневой объект и есть предикт
    // (ключи: Wake, N1, N2, N3, REM; значения: списки интервалов [[start,end],...])
    if (prediction == null && decodedMap.isNotEmpty) {
      const knownStages = ['w', 'wake', 'n1', 'n2', 'n3', 'rem'];
      final hasStageKeys = decodedMap.keys.any(
          (k) => knownStages.contains(k.toString().toLowerCase()));
      if (hasStageKeys) {
        prediction = Map<String, dynamic>.from(decodedMap);
      }
    }

    return PredictResult(prediction: prediction, jsonIndex: jsonIndex);
  }

  /// Проверяет доступность сервера по baseUrl.
  /// Возвращает null при успехе, иначе — текст ошибки.
  Future<String?> checkConnection(String url) async {
    final base = url.trim();
    if (base.isEmpty) return 'Укажите адрес сервера';
    String normalized = base;
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    if (normalized.endsWith('/')) normalized = normalized.substring(0, normalized.length - 1);
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
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Connection refused')) {
        return 'Сервер недоступен. Проверьте:\n• Телефон и ПК в одной Wi‑Fi\n• IP и порт (например :8000)\n• Firewall на ПК\n• Docker: docker run -p 8000:8000 ...';
      }
      if (msg.contains('timeout') || msg.contains('Превышено')) {
        return 'Таймаут. Сервер не отвечает за 5 сек.';
      }
      return msg.length > 80 ? '${msg.substring(0, 80)}...' : msg;
    }
  }

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
