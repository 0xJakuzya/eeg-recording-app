import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/models/recording_models.dart';

class FilesController {
  const FilesController();

  SettingsController get settingsController => Get.find<SettingsController>();

  Future<Directory> get recordingsDirectory async {
    final customPath = settingsController.recordingDirectory.value;
    return (customPath != null && customPath.isNotEmpty)
        ? Directory(customPath)
        : getApplicationDocumentsDirectory();
  }

  Future<RecordingDirectoryContent> listDirectory({Directory? directory}) async {
    final root = await recordingsDirectory;
    final dir = directory ?? root;
    final isRoot = dir.path == root.path;

    final subdirs = <Directory>[];
    final files = <RecordingFileInfo>[];

    await for (final entity
        in dir.list(recursive: false, followLinks: false)) { if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (isRoot && !RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(name)) {
          continue;
        }
        subdirs.add(entity);
      } 
      else if (entity is File) {
        final path = entity.path.toLowerCase();
        if (!path.endsWith(RecordingConstants.recordingFileExtension)) continue;
        final stat = await entity.stat();
        files.add(RecordingFileInfo(
          file: entity,
          name: fileName(entity),
          modified: stat.modified,
          sizeBytes: stat.size,
        ));
      }
    }
    
    // sorted 
    subdirs.sort( (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    files.sort((a, b) => b.modified.compareTo(a.modified));

    return RecordingDirectoryContent(
      directory: dir,
      subdirectories: subdirs,
      files: files,
    );
  }

  // list recording files
  Future<List<RecordingFileInfo>> listRecordingFiles() async => (await listDirectory()).files;

  // get file name
  String fileName(File file) => file.path.split(Platform.pathSeparator).last;

  // delete file
  Future<void> deleteFile(RecordingFileInfo info) async { 
    if (await info.file.exists()) await info.file.delete();
  }

  // delete directory
  Future<void> deleteDirectory(Directory dir) async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // share files 
  Future<void> shareFile(RecordingFileInfo info) async {
    if (!await info.file.exists()) return;
    final xFile = XFile(info.file.path);
    await Share.shareXFiles([xFile], text: 'EEG запись: ${info.name}');
  }
}