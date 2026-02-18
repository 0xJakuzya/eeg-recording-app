import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/core/polysomnography_constants.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/processed_session_models.dart';
import 'package:ble_app/views/session_details_page.dart';
import 'package:ble_app/utils/extension.dart';

class FilesProcessedPage extends StatefulWidget {
  const FilesProcessedPage({super.key});

  @override
  State<FilesProcessedPage> createState() => FilesProcessedPageState();
}

class FilesProcessedPageState extends State<FilesProcessedPage> {
  static const FilesController filesController = FilesController();

  List<ProcessedSession> _sessions = [];
  bool _isProcessing = false;
  Future<List<ProcessedSession>>? _sessionsFuture;

  Future<List<ProcessedSession>> loadTodaySessions() async {
    final root = await filesController.recordingsDirectory;
    final todayName =
        DateTime.now().toLocal().format('dd.MM.yyyy');
    final dateRegex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
    Directory dateDir;
    final rootName = root.path.split(Platform.pathSeparator).last;
    if (dateRegex.hasMatch(rootName)) {
      dateDir = root;
    } else {
      final rootContent =
          await filesController.listDirectory(directory: root);
      final dateDirs = rootContent.subdirectories.where((dir) {
        final name = dir.path.split(Platform.pathSeparator).last;
        return dateRegex.hasMatch(name);
      }).toList();

      Directory? todayDir;
      for (final dir in dateDirs) {
        final name = dir.path.split(Platform.pathSeparator).last;
        if (name == todayName) {
          todayDir = dir;
          break;
        }
      }

      if (todayDir != null) {
        dateDir = todayDir;
      } else {
        dateDirs.sort((a, b) {
          DateTime parse(String s) {
            final parts = s.split('.');
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            return DateTime(year, month, day);
          }

          final aName = a.path.split(Platform.pathSeparator).last;
          final bName = b.path.split(Platform.pathSeparator).last;
          final aDate = parse(aName);
          final bDate = parse(bName);
          return bDate.compareTo(aDate);
        });
        dateDir = dateDirs.first;
      }
    }
    final dateEntities =
        await dateDir.list(recursive: false, followLinks: false).toList();

    final sessionDirRegex = RegExp(r'^session_\d+$');
    final sessions = <ProcessedSession>[];
    final sessionDirs = <Directory>[];
    for (final entity in dateEntities) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (sessionDirRegex.hasMatch(name)) {
          sessionDirs.add(entity);
        }
      }
    }
    if (sessionDirs.isNotEmpty) {
      for (final dir in sessionDirs) {
        sessions.add(
          ProcessedSession.fromDirectory(
            dir,
            status: ProcessingStatus.unknown,
          ),
        );
      }
    } else {
      for (final entity in dateEntities) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name
              .toLowerCase()
              .endsWith(RecordingConstants.recordingFileExtension)) {
            continue;
          }

          final id = name;
          sessions.add(
            ProcessedSession(
              id: id,
              directory: entity.parent,
              status: ProcessingStatus.unknown,
            ),
          );
        }
      }
    }
    sessions.sort((a, b) => a.id.compareTo(b.id));
    return sessions;
  }

  Future<List<File>> _getSessionFiles(ProcessedSession session) async {
    final dir = session.directory;
    final files = <File>[];

    await for (final entity
        in dir.list(recursive: false, followLinks: false)) {
      if (entity is File) {
        final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
        if (name.endsWith('.txt') || name.endsWith('.edf')) {
          files.add(entity);
        }
      }
    }

    if (files.isEmpty) {
      final singleFile =
          File('${dir.path}${Platform.pathSeparator}${session.id}');
      if (await singleFile.exists()) {
        final name = session.id.toLowerCase();
        if (name.endsWith('.txt') || name.endsWith('.edf')) {
          files.add(singleFile);
        }
      }
    }

    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _processSession(
      BuildContext context, ProcessedSession session) async {
    final files = await _getSessionFiles(session);
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет файлов для обработки')),
      );
      return;
    }

    // Константы: всегда первый файл, данные без запросов пользователю
    const int fileIndex = 0;
    const int patientId = PolysomnographyConstants.defaultPatientId;
    const double samplingFreq =
        PolysomnographyConstants.defaultSamplingFrequencyHz;

    setState(() => _isProcessing = true);

    try {
      final baseUrl = PolysomnographyConstants.defaultBaseUrl;
      final uploadUri =
          Uri.parse('$baseUrl${PolysomnographyConstants.saveUserFilePath}');

      for (var i = 0; i < files.length; i++) {
        final fileToUpload = files[i];
        final storageKey =
            PolysomnographyConstants.storageKey(session.id, i + 1);

        // Как PolysomnographyApiService — query params (сервер может ожидать только их)
        final uriWithQuery = uploadUri.replace(queryParameters: {
          'patient_id': patientId.toString(),
          'patient_name': storageKey,
          'sampling_frequency': samplingFreq.toString(),
        });
        final request = http.MultipartRequest('POST', uriWithQuery);

        final filename = fileToUpload.path.split(Platform.pathSeparator).last;
        final isEdf = filename.toLowerCase().endsWith('.edf');
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            fileToUpload.path,
            filename: filename,
            contentType: isEdf
                ? MediaType('application', 'octet-stream')
                : MediaType('text', 'plain'),
          ),
        );

        final uploadResponse = await request.send();
        final uploadBody = await uploadResponse.stream.bytesToString();

        if (uploadResponse.statusCode != 200) {
          throw Exception(
              'Ошибка загрузки: ${uploadResponse.statusCode} $uploadBody');
        }
      }

      final fileToPredict = files[fileIndex];
      final isEdf = fileToPredict.path.toLowerCase().endsWith('.edf');
      final predictStorageKey =
          PolysomnographyConstants.storageKey(session.id, fileIndex + 1);

      // save_predict_json
      final predictBase =
          '$baseUrl${PolysomnographyConstants.savePredictJsonPath}';
      http.Response predictResponse;

      if (PolysomnographyConstants.predictUseQueryParams) {
        var predictUri = Uri.parse(predictBase).replace(queryParameters: {
          'patient_id': patientId.toString(),
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
          'patient_id': patientId,
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
        } catch (_) {}
        throw Exception(
            'Ошибка предикта ${predictResponse.statusCode}: $detail');
      }

      final decoded = jsonDecode(predictResponse.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Некорректный ответ сервера');
      }

      // Индекс сохранённого JSON-файла (используется в sleep_graph для построения гипнограммы)
      int? jsonIndex;
      for (final key in ['index', 'json_index', 'file_index', 'id']) {
        if (decoded[key] != null) {
          jsonIndex = int.tryParse(decoded[key].toString());
          if (jsonIndex != null) break;
        }
      }
      Map<String, dynamic>? prediction;
      if (decoded['prediction'] is Map) {
        prediction =
            Map<String, dynamic>.from(decoded['prediction'] as Map);
      }

      final updated = session.copyWith(
        predictionStatus: PredictionStatus.done,
        prediction: prediction,
        jsonIndex: jsonIndex,
      );

      final idx = _sessions.indexWhere((s) => s.id == session.id);
      if (idx >= 0) {
        setState(() {
          _sessions = List.from(_sessions)..[idx] = updated;
        });
      }

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailsPage(session: updated),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _onSessionTap(ProcessedSession session) {
    if (session.predictionStatus == PredictionStatus.done) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailsPage(session: session),
        ),
      );
    } else {
      _processSession(context, session);
    }
  }

  String _statusText(PredictionStatus status) {
    switch (status) {
      case PredictionStatus.notStarted:
        return 'Предикт не запускался';
      case PredictionStatus.inProgress:
        return 'Предикт выполняется';
      case PredictionStatus.done:
        return 'Предикт готов';
      case PredictionStatus.failed:
        return 'Ошибка предикта';
    }
  }

  Icon _statusIcon(PredictionStatus status, BuildContext context) {
    switch (status) {
      case PredictionStatus.notStarted:
        return Icon(
          Icons.do_disturb,
          color: Theme.of(context).colorScheme.outline,
        );
      case PredictionStatus.inProgress:
        return Icon(
          Icons.autorenew,
          color: Theme.of(context).colorScheme.primary,
        );
      case PredictionStatus.done:
        return Icon(
          Icons.check_circle,
          color: Colors.green,
        );
      case PredictionStatus.failed:
        return Icon(
          Icons.error,
          color: Colors.red,
        );
    }
  }

  @override
  void initState() {
    super.initState();
    refreshSessions();
  }

  void refreshSessions() {
    setState(() {
      _sessions = [];
      _sessionsFuture = loadTodaySessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обработка файлов'),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<ProcessedSession>>(
            future: _sessionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Ошибка загрузки сессий: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final sessions = snapshot.data ?? <ProcessedSession>[];
              if (_sessions.isEmpty && sessions.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _sessions = sessions);
                });
              }
              final displaySessions = _sessions.isNotEmpty ? _sessions : sessions;

              if (displaySessions.isEmpty) {
                return const Center(
                  child: Text('На сегодня сессии не найдены'),
                );
              }

              return ListView.separated(
                itemCount: displaySessions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final session = displaySessions[index];
                  final statusLabel = _statusText(session.predictionStatus);

                  return ListTile(
                    leading: Icon(
                      Icons.folder,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(session.id),
                    subtitle: Text(statusLabel),
                    trailing: _statusIcon(session.predictionStatus, context),
                    onTap: _isProcessing
                        ? null
                        : () => _onSessionTap(session),
                  );
                },
              );
            },
          ),
          if (_isProcessing)
            AbsorbPointer(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
