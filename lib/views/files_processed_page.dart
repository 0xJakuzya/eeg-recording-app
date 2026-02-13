import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/processed_session_models.dart';
import 'package:ble_app/views/session_details_page.dart';
import 'package:ble_app/utils/extension.dart';

class FilesProcessedPage extends StatelessWidget {
  const FilesProcessedPage({super.key});

  static const FilesController filesController = FilesController();

  Future<List<ProcessedSession>> loadTodaySessions() async {

    final root = await filesController.recordingsDirectory;
    final todayName = DateTime.now()
        .toLocal()
        .format('dd.MM.yyyy');
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

  String statusText(PredictionStatus status) {
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

  Icon statusIcon(PredictionStatus status, BuildContext context) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обработка файлов'),
      ),
      body: FutureBuilder<List<ProcessedSession>>(
        future: loadTodaySessions(),
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

          if (sessions.isEmpty) {
            return const Center(
              child: Text('На сегодня сессии не найдены'),
            );
          }

          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final statusLabel = statusText(session.predictionStatus);

              return ListTile(
                leading: Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(session.id),
                subtitle: Text(statusLabel),
                trailing: statusIcon(session.predictionStatus, context),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }
}