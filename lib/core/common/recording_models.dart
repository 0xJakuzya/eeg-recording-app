import 'dart:io';

import 'package:ble_app/core/constants/polysomnography_constants.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

// file metadata for directory browser; provides formatted date/size strings
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

  // estimated from file size (~55 bytes per CSV line) to avoid reading large files
  Duration get duration {
    const avgBytesPerLine = 55;
    const hz = PolysomnographyConstants.defaultSamplingFrequencyHz;
    final samples = sizeBytes ~/ avgBytesPerLine;
    return Duration(milliseconds: (samples * 1000 / hz).round());
  }
}

// directory content: folder reference, subdirs and files for browser ui
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