import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/core/app_theme.dart';
import 'package:ble_app/core/polysomnography_constants.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/processed_session_models.dart';
import 'package:ble_app/services/polysomnography_service.dart';
import 'package:ble_app/views/session_details_page.dart';
import 'package:ble_app/utils/extension.dart';

class FilesProcessedPage extends StatefulWidget {
  const FilesProcessedPage({super.key});

  @override
  State<FilesProcessedPage> createState() => FilesProcessedPageState();
}

class FilesProcessedPageState extends State<FilesProcessedPage> {
  static const FilesController filesController = FilesController();
  final PolysomnographyApiService polysomnographyService =
      PolysomnographyApiService(
    baseUrl: PolysomnographyConstants.defaultBaseUrl,
  );

  List<ProcessedSession> cachedSessions = [];
  bool isProcessingInProgress = false;
  Future<List<ProcessedSession>>? sessionsLoadFuture;

  static int _sessionNumber(String id) {
    final m = RegExp(r'session_(\d+)$').firstMatch(id);
    return m != null ? (int.tryParse(m.group(1) ?? '') ?? -1) : -1;
  }

  Future<List<ProcessedSession>> loadTodaySessions() async {
    final root = await filesController.recordingsDirectory;
    final dateDir = await resolveDateDirectory(root);
    final dateEntities =
        await dateDir.list(recursive: false, followLinks: false).toList();
    final sessions = await collectSessionsFromDateDir(dateEntities);
    sessions.sort((a, b) {
      final aNum = _sessionNumber(a.id);
      final bNum = _sessionNumber(b.id);
      if (aNum >= 0 && bNum >= 0) return aNum.compareTo(bNum);
      return a.id.compareTo(b.id);
    });
    return sessions;
  }

  Future<Directory> resolveDateDirectory(Directory root) async {
    final dateRegex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
    final rootName = root.path.split(Platform.pathSeparator).last;
    if (dateRegex.hasMatch(rootName)) return root;

    final rootContent = await filesController.listDirectory(directory: root);
    final dateDirs = rootContent.subdirectories
        .where((d) => dateRegex.hasMatch(
            d.path.split(Platform.pathSeparator).last))
        .toList();

    final todayName = DateTime.now().toLocal().format('dd.MM.yyyy');
    for (final dir in dateDirs) {
      if (dir.path.split(Platform.pathSeparator).last == todayName) {
        return dir;
      }
    }

    dateDirs.sort((a, b) {
      DateTime parse(String s) {
        final parts = s.split('.');
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      final aDate = parse(a.path.split(Platform.pathSeparator).last);
      final bDate = parse(b.path.split(Platform.pathSeparator).last);
      return bDate.compareTo(aDate);
    });
    return dateDirs.first;
  }

  Future<List<ProcessedSession>> collectSessionsFromDateDir(
      List<FileSystemEntity> entities) async {
    final sessionDirRegex = RegExp(r'^session_\d+$');
    final sessions = <ProcessedSession>[];

    final sessionDirs = entities.whereType<Directory>().where((d) {
      final name = d.path.split(Platform.pathSeparator).last;
      return sessionDirRegex.hasMatch(name);
    }).toList();

    if (sessionDirs.isNotEmpty) {
      for (final dir in sessionDirs) {
        sessions.add(ProcessedSession.fromDirectory(dir,
            status: ProcessingStatus.unknown));
      }
      return sessions;
    }

    for (final entity in entities) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.toLowerCase()
          .endsWith(RecordingConstants.recordingFileExtension)) {
        continue;
      }
      sessions.add(ProcessedSession(
        id: name,
        directory: entity.parent,
        status: ProcessingStatus.unknown,
      ));
    }
    return sessions;
  }

  Future<List<File>> getSessionFiles(ProcessedSession session) async {
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

  Future<void> processSession(
      BuildContext context, ProcessedSession session) async {
    final files = await getSessionFiles(session);
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет файлов для обработки')),
      );
      return;
    }

    const int fileIndex = 0;

    setState(() => isProcessingInProgress = true);

    try {
      await polysomnographyService.uploadSessionFiles(
        files: files,
        sessionId: session.id,
      );

      final fileToPredict = files[fileIndex];
      final isEdf = fileToPredict.path.toLowerCase().endsWith('.edf');

      final result = await polysomnographyService.requestPredict(
        sessionId: session.id,
        fileIndex: fileIndex,
        isEdf: isEdf,
      );

      final updated = session.copyWith(
        predictionStatus: PredictionStatus.done,
        prediction: result.prediction,
        jsonIndex: result.jsonIndex,
      );

      final sessionIndex = cachedSessions.indexWhere((s) => s.id == session.id);
      if (sessionIndex >= 0) {
        setState(() {
          cachedSessions = List.from(cachedSessions)..[sessionIndex] = updated;
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
        setState(() => isProcessingInProgress = false);
      }
    }
  }

  void onSessionTap(ProcessedSession session) {
    if (session.predictionStatus == PredictionStatus.done) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailsPage(session: session),
        ),
      );
    } else {
      processSession(context, session);
    }
  }

  String getPredictionStatusLabel(PredictionStatus status) {
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

  Icon getPredictionStatusIcon(PredictionStatus status, BuildContext context) {
    switch (status) {
      case PredictionStatus.notStarted:
        return const Icon(Icons.do_disturb, color: AppTheme.textMuted);
      case PredictionStatus.inProgress:
        return const Icon(Icons.autorenew, color: AppTheme.accentSecondary);
      case PredictionStatus.done:
        return const Icon(Icons.check_circle, color: AppTheme.statusPredictionReady);
      case PredictionStatus.failed:
        return const Icon(Icons.error, color: AppTheme.statusFailed);
    }
  }

  BoxDecoration _sessionCardDecoration(PredictionStatus status) {
    final borderColor = status == PredictionStatus.done
        ? AppTheme.statusPredictionReady.withValues(alpha: 0.4)
        : AppTheme.borderSubtle;
    final hasGlow = status == PredictionStatus.done;
    return BoxDecoration(
      color: AppTheme.backgroundSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
      boxShadow: hasGlow
          ? [
              BoxShadow(
                color: AppTheme.statusPredictionReady.withValues(alpha: 0.12),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ]
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    refreshSessions();
  }

  void refreshSessions() {
    setState(() {
      cachedSessions = [];
      sessionsLoadFuture = loadTodaySessions();
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
            future: sessionsLoadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentSecondary,
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Ошибка загрузки сессий: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                );
              }

              final sessions = snapshot.data ?? <ProcessedSession>[];
              if (cachedSessions.isEmpty && sessions.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => cachedSessions = sessions);
                });
              }
              final displaySessions =
                  cachedSessions.isNotEmpty ? cachedSessions : sessions;

              if (displaySessions.isEmpty) {
                return Center(
                  child: Text(
                    'На сегодня сессии не найдены',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: displaySessions.length,
                itemBuilder: (context, index) {
                  final session = displaySessions[index];
                  final statusLabel =
                      getPredictionStatusLabel(session.predictionStatus);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: isProcessingInProgress
                          ? null
                          : () => onSessionTap(session),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _sessionCardDecoration(
                            session.predictionStatus),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder,
                              color: AppTheme.accentPrimary,
                              size: 28,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.id,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    statusLabel,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            getPredictionStatusIcon(
                                session.predictionStatus, context),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (isProcessingInProgress)
            AbsorbPointer(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
