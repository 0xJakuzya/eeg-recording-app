import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/utils/extension.dart';

class FilesController {
  const FilesController();

  SettingsController get settingsController => Get.find<SettingsController>();

  Future<Directory> get recordingsDirectory async {
    final String? customPath = settingsController.recordingDirectory.value;

    if (customPath != null && customPath.isNotEmpty) {
      return Directory(customPath);
    }

    return getApplicationDocumentsDirectory();
  }

  Future<RecordingDirectoryContent> listDirectory({Directory? directory}) async {
    final root = await recordingsDirectory;
    final dir = directory ?? root;

    if (!await dir.exists()) {
      return RecordingDirectoryContent(
        directory: dir,
        subdirectories: const <Directory>[],
        files: const <RecordingFileInfo>[],
      );
    }

    final entities =
        await dir.list(recursive: false, followLinks: false).toList();

    final subdirs = <Directory>[];
    final files = <RecordingFileInfo>[];

    final isRoot = dir.path == root.path;

    for (final entity in entities) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (isRoot) {
          // at root: show only date folders like 10.02.2026
          final isDateDir =
              RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(name);
          if (!isDateDir) {
            continue;
          }
        }
        subdirs.add(entity);
      } else if (entity is File) {
        final name = entity.path.toLowerCase();
        if (!name.endsWith('.csv')) continue;
        final stat = await entity.stat();
        files.add(
          RecordingFileInfo(
            file: entity,
            name: fileName(entity),
            modified: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }
    }

    subdirs.sort(
      (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
    );
    files.sort((a, b) => b.modified.compareTo(a.modified));

    return RecordingDirectoryContent(
      directory: dir,
      subdirectories: subdirs,
      files: files,
    );
  }

  Future<List<RecordingFileInfo>> listRecordingFiles() async {
    final content = await listDirectory();
    return content.files;
  }

  String fileName(File file) {
    final parts = file.path.split(Platform.pathSeparator);
    return parts.isNotEmpty ? parts.last : file.path;
  }

  Future<void> deleteFile(RecordingFileInfo info) async {
    final file = info.file;
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteDirectory(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> shareFile(RecordingFileInfo info) async {
    final file = info.file;
    if (!await file.exists()) return;
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      text: 'EEG запись: ${info.name}',
    );
  }
}

class RecordingFileInfo {
  final File file;
  final String name;
  final DateTime modified;
  final int sizeBytes;
  RecordingFileInfo({
    required this.file,
    required this.name,
    required this.modified,
    required this.sizeBytes,
  });
  String get formattedModified => modified.toLocal().format('dd.MM.yyyy HH:mm');
  String get formattedSize => sizeBytes.formatBytes();
}

class RecordingDirectoryContent {
  final Directory directory;
  final List<Directory> subdirectories;
  final List<RecordingFileInfo> files;

  RecordingDirectoryContent({
    required this.directory,
    required this.subdirectories,
    required this.files,
  });
}


