import 'dart:io';
import 'package:ble_app/utils/extension.dart';

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


