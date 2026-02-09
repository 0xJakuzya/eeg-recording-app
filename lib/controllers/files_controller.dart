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

  Future<List<RecordingFileInfo>> listRecordingFiles() async {
    final dir = await recordingsDirectory;

    if (!await dir.exists()) {
      return <RecordingFileInfo>[];
    }

    final entries = await dir
        .list(recursive: false, followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .toList();

    final csvFiles = entries.where((file) {
      final name = file.path.toLowerCase();
      return name.endsWith('.csv');
    }).toList();

    final infos = <RecordingFileInfo>[];
    for (final file in csvFiles) {
      final stat = await file.stat();
      infos.add(
        RecordingFileInfo(
          file: file,
          name: fileName(file),
          modified: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    infos.sort((a, b) => b.modified.compareTo(a.modified));
    return infos;
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

