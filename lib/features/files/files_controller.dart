import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/core/constants/recording_constants.dart';
import 'package:ble_app/core/common/recording_models.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

class SessionPath {
  const SessionPath({
    required this.sessionDirPath,
    required this.filename,
  });
  final String sessionDirPath;
  final String filename;
}

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

    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is Directory) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (isRoot && !RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(name)) {
          continue;
        }
        subdirs.add(entity);
      } else if (entity is File) {
        final path = entity.path.toLowerCase();
        final isRecordingFile = RecordingConstants.recordingFileExtensions
            .any((ext) => path.endsWith(ext));
        if (!isRecordingFile) continue;
        final stat = await entity.stat();
        files.add(RecordingFileInfo(
          file: entity,
          name: fileName(entity),
          modified: stat.modified,
          sizeBytes: stat.size,
        ));
      }
    }

    subdirs.sort((a, b) {
      final aName = a.path.split(Platform.pathSeparator).last;
      final bName = b.path.split(Platform.pathSeparator).last;
      final aMatch = sessionFolderPattern.firstMatch(aName);
      final bMatch = sessionFolderPattern.firstMatch(bName);
      if (aMatch != null && bMatch != null) {
        final an = int.tryParse(aMatch.group(1) ?? '') ?? 0;
        final bn = int.tryParse(bMatch.group(1) ?? '') ?? 0;
        return an.compareTo(bn);
      }
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    files.sort((a, b) => b.modified.compareTo(a.modified));

    return RecordingDirectoryContent(
      directory: dir,
      subdirectories: subdirs,
      files: files,
    );
  }

  Future<List<RecordingFileInfo>> listRecordingFiles() async =>
      (await listDirectory()).files;

  String fileName(File file) => file.path.split(Platform.pathSeparator).last;

  Future<void> deleteFile(RecordingFileInfo info) async {
    if (await info.file.exists()) await info.file.delete();
  }

  Future<void> deleteDirectory(Directory dir) async {
    if (!await dir.exists()) return;
    
    final name = dir.path.split(Platform.pathSeparator).last;
    final sessionMatch = RegExp(r'^session_(\d+)$').firstMatch(name);
    final dateMatch = RegExp(r'^(\d{2}\.\d{2}\.\d{4})$').firstMatch(name);
    
    await dir.delete(recursive: true);
    
    if (dateMatch != null) {
      final date = dateMatch.group(1)!;
      await settingsController.resetSessionCounterForDate(date);
    } else if (sessionMatch != null) {
      final parent = dir.parent;
      final parentName = parent.path.split(Platform.pathSeparator).last;
      final parentDateMatch = RegExp(r'^(\d{2}\.\d{2}\.\d{4})$').firstMatch(parentName);
      if (parentDateMatch != null) {
        final date = parentDateMatch.group(1)!;
        final recalculated = await settingsController.recalculateSessionNumber(parent.path);
        final prefs = await SharedPreferences.getInstance();
        final lastDate = prefs.getString(RecordingConstants.keyLastSessionDate);
        if (lastDate == date) {
          await prefs.setInt(RecordingConstants.keyLastSessionNumber, recalculated - 1);
          settingsController.lastSessionNumber.value = recalculated - 1;
        }
      }
    }
    await syncSessionCounter();
  }

  static final sessionFolderPattern = RegExp(r'^session_(\d+)$');

  Future<int> getMaxExistingSessionNumber() async {
    int maxSession = 0;
    final root = await recordingsDirectory;
    if (!await root.exists()) return 0;

    await for (final entity in root.list(recursive: false, followLinks: false)) {
      if (entity is! Directory) continue;
      final dateName = entity.path.split(Platform.pathSeparator).last;
      if (!RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(dateName)) continue;

      await for (final sub in entity.list(recursive: false, followLinks: false)) {
        if (sub is! Directory) continue;
        final sessionName = sub.path.split(Platform.pathSeparator).last;
        final match = sessionFolderPattern.firstMatch(sessionName);
        if (match != null) {
          final n = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (n > maxSession) maxSession = n;
        }
      }
    }
    return maxSession;
  }

  Future<void> syncSessionCounter() async {
    final maxSession = await getMaxExistingSessionNumber();
    await settingsController.setLastSessionNumber(maxSession);
  }

  Future<void> shareFile(RecordingFileInfo info) async {
    if (!await info.file.exists()) return;
    final xFile = XFile(info.file.path);
    await Share.shareXFiles([xFile], text: 'EEG запись: ${info.name}');
  }

  Future<void> shareFiles(List<RecordingFileInfo> files) async {
    final existing = <XFile>[];
    for (final info in files) {
      if (await info.file.exists()) existing.add(XFile(info.file.path));
    }
    if (existing.isEmpty) return;
    await Share.shareXFiles(
      existing,
      text: existing.length == 1
          ? 'EEG запись: ${files.first.name}'
          : 'EEG записи (${existing.length} файлов)',
    );
  }

  Future<String> resolveRootDir() async {
    final customDir = settingsController.recordingDirectory.value;
    if (customDir != null && customDir.isNotEmpty) return customDir;
    final appDir = await getApplicationDocumentsDirectory();
    return appDir.path;
  }

  String joinPath(String parent, String child) =>
      parent.endsWith(Platform.pathSeparator)
          ? '$parent$child'
          : '$parent${Platform.pathSeparator}$child';

  /// Возвращает путь для новой сессии записи. Каждый вызов — новая папка session_N.
  Future<SessionPath> getNextSessionPath() async {
    final now = DateTime.now();
    final rootDir = await resolveRootDir();
    final dateFolderName = now.format('dd.MM.yyyy');
    final dateDirPath = joinPath(rootDir, dateFolderName);

    final sessionNumber = await settingsController.getNextSessionNumber();

    final sessionFolderName = 'session_$sessionNumber';
    final sessionDirPath = joinPath(dateDirPath, sessionFolderName);
    await Directory(sessionDirPath).create(recursive: true);
    final ext = settingsController.recordingFileExtension.value;
    final filename = 'session_$sessionNumber$ext';
    return SessionPath(sessionDirPath: sessionDirPath, filename: filename);
  }
}
