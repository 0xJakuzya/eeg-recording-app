import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/processed_session.dart';
import 'package:ble_app/views/session_details_page.dart';
import 'package:ble_app/utils/extension.dart';

class FilesProcessedPage extends StatelessWidget {
  const FilesProcessedPage({super.key});

  static const FilesController filesController = FilesController();

  Future<List<ProcessedSession>> loadTodaySessions() async {
    // Базовая директория записей — та же, с которой работает FilesPage.
    final root = await filesController.recordingsDirectory;
    final todayName = DateTime.now()
        .toLocal()
        .format('dd.MM.yyyy');
    final dateRegex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');

    // Определяем "дату-сессию", с которой будем работать.
    // 1) Если пользователь в настройках сразу выбрал папку конкретной даты
    //    (…/11.02.2026) — используем её.
    // 2) Иначе ищем внутри root подпапки с датами и берём:
    //    - либо папку за сегодня,
    //    - либо самую свежую по дате.
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

      if (dateDirs.isEmpty) {
        // В корне нет папок с датами — сессий нет.
        return <ProcessedSession>[];
      }

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
        // Берём самую "свежую" дату.
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

    // Теперь внутри выбранной папки даты нам нужно найти "сессии".
    // Структура записи создаётся RecordingController:
    //   <root>/<dd.MM.yyyy>/session_N/session_N.txt
    //
    // Но могут быть и старые/нестандартные записи, когда файлы лежат
    // прямо в датовом каталоге. Поэтому:
    //  - сначала ищем подпапки вида session_N;
    //  - если подпапок нет, то считаем отдельной сессией каждый .txt файл.

    final dateEntities =
        await dateDir.list(recursive: false, followLinks: false).toList();

    final sessionDirRegex = RegExp(r'^session_\d+$');
    final sessions = <ProcessedSession>[];

    // 1) Ищем подпапки session_N
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
      // Нашли "правильные" каталоги сессий — работаем с ними.
      for (final dir in sessionDirs) {
        sessions.add(
          ProcessedSession.fromDirectory(
            dir,
            status: ProcessingStatus.unknown,
          ),
        );
      }
    } else {
      // Подкаталогов session_N нет — трактуем каждый .txt как отдельную сессию.
      for (final entity in dateEntities) {
        if (entity is File) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name
              .toLowerCase()
              .endsWith(RecordingConstants.recordingFileExtension)) {
            continue;
          }

          final id = name; // для старых файлов оставляем полное имя.
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

    // Упорядочим: сначала по имени (session_1, session_2, ... или по названию файла).
    sessions.sort((a, b) => a.id.compareTo(b.id));

    return sessions;
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
              final statusLabel = _statusText(session.predictionStatus);

              return ListTile(
                leading: Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(session.id),
                subtitle: Text(statusLabel),
                trailing: _statusIcon(session.predictionStatus, context),
                onTap: () {
                  if (session.predictionStatus == PredictionStatus.done &&
                      session.prediction != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            SessionDetailsPage(session: session),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}