import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/features/files/files_controller.dart';
import 'package:ble_app/features/files/csv_view_page.dart';
import 'package:ble_app/features/files/widgets/files_selection_bar.dart';
import 'package:ble_app/features/navigation/navigation_controller.dart';
import 'package:ble_app/features/polysomnography/polysomnography_controller.dart';
import 'package:ble_app/features/polysomnography/polysomnography_service.dart';
import 'package:ble_app/features/polysomnography/processed_files_page.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/core/common/recording_models.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/core/constants/polysomnography_constants.dart';

final GlobalKey<FilesPageState> filesPageKey = GlobalKey<FilesPageState>();

// directory browser for dd.mm.yyyy / session_N; long-press → selection mode; share, delete, polysomnography upload
class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  static const FilesController filesController = FilesController();

  @override
  State<FilesPage> createState() => FilesPageState();
}

// holds directory stack, selection state, current listing; drives FutureBuilder
class FilesPageState extends State<FilesPage> {
  late Future<RecordingDirectoryContent> directoryFuture;
  final Set<String> selectedPaths = <String>{};
  List<RecordingFileInfo> currentFiles = <RecordingFileInfo>[];
  List<Directory> currentDirectories = <Directory>[];
  bool selectionMode = false;
  Directory? currentDirectory;
  final List<Directory> directoryStack = <Directory>[];
  // uses effectivePolysomnographyBaseUrl from settings
  PolysomnographyApiService get polysomnographyService =>
      PolysomnographyApiService(
        baseUrlGetter: () =>
            Get.find<SettingsController>().effectivePolysomnographyBaseUrl,
      );

  @override
  void initState() {
    super.initState();
    reloadDirectory();
  }

  // clear selection, refresh list via FilesController
  void reloadDirectory() {
    selectedPaths.clear();
    selectionMode = false;
    directoryFuture =
        FilesPage.filesController.listDirectory(directory: currentDirectory);
  }

  // reset to root, clear stack, reload
  void refreshFiles() {
    setState(() {
      currentDirectory = null;
      directoryStack.clear();
      reloadDirectory();
    });
  }

  // pop directory stack, go to parent
  void goUpDirectory() {
    if (directoryStack.isEmpty) return;
    setState(() {
      currentDirectory = directoryStack.removeLast();
      reloadDirectory();
    });
  }

  Future<void> deleteSelectedItems() async {
    final toDeleteFiles = currentFiles
        .where((f) => selectedPaths.contains(f.file.path))
        .toList();
    final toDeleteDirs = currentDirectories
        .where((d) => selectedPaths.contains(d.path))
        .toList();
    if (toDeleteFiles.isEmpty && toDeleteDirs.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить файлы'),
            content: Text(
                'Удалить выбранные объекты (${toDeleteFiles.length + toDeleteDirs.length})?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.statusFailed,
                  foregroundColor: AppTheme.textPrimary,
                ),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    for (final dir in toDeleteDirs) {
      await FilesPage.filesController.deleteDirectory(dir);
    }
    if (toDeleteDirs.isNotEmpty) {
      await FilesPage.filesController.syncSessionCounter();
    }

    for (final info in toDeleteFiles) {
      await FilesPage.filesController.deleteFile(info);
    }

    if (!mounted) return;
    refreshFiles();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Удалено объектов: ${toDeleteFiles.length + toDeleteDirs.length}'),
      ),
    );
  }

  // single-file delete with confirmation dialog
  Future<void> confirmAndDeleteSingle(
      BuildContext context, RecordingFileInfo info) async {
    final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить файл'),
            content: Text('Вы уверены, что хотите удалить файл "${info.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.statusFailed,
                  foregroundColor: AppTheme.textPrimary,
                ),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!result) return;

    await FilesPage.filesController.deleteFile(info);
    refreshFiles();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Файл "${info.name}" удалён')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'На уровень выше',
              onPressed: directoryStack.isEmpty ? null : () => goUpDirectory(),
            ),
          ],
        ),
        title: Text(
          'Файлы записи',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить список',
            onPressed: () => refreshFiles(),
          ),
        ],
      ),
      bottomNavigationBar: selectionMode
          ? FilesSelectionBar(
              selectedCount: selectedPaths.length,
              totalItems: currentFiles.length + currentDirectories.length,
              allSelected: allSelected,
              hasSelectedFiles: hasSelectedFiles,
              onToggleSelectAll: handleToggleSelectAll,
              onShareSelected: () async {
                final selectedFileInfos = currentFiles
                    .where((f) => selectedPaths.contains(f.file.path))
                    .toList();
                if (selectedFileInfos.isEmpty) return;
                await FilesPage.filesController.shareFiles(selectedFileInfos);
              },
              onUploadSelected:
                  hasSelectedSessionFolders() || isAtDateLevel()
                      ? null
                      : () async {
                          final selectedFileInfos = currentFiles
                              .where((f) =>
                                  selectedPaths.contains(f.file.path))
                              .toList();
                          if (selectedFileInfos.isEmpty) return;
                          await showPolysomnographyUploadDialog(
                            context,
                            selectedFileInfos,
                          );
                        },
              onDeleteSelected: deleteSelectedItems,
            )
          : null,
      body: FutureBuilder<RecordingDirectoryContent>(
        future: directoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки файлов: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          final content = snapshot.data;
          if (content == null) return const SizedBox.shrink();

          currentDirectory = content.directory;
          final dirs = content.subdirectories;
          final files = content.files;
          currentDirectories = dirs;
          currentFiles = files;
          final hasEntries = dirs.isNotEmpty || files.isNotEmpty;
          if (!hasEntries) {
            return const Center(
              child: Text('Записанные файлы не найдены'),
            );
          }

          final itemCount = dirs.length + files.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index < dirs.length) {
                      final dir = dirs[index];
                      final segments = dir.path.split(Platform.pathSeparator);
                      final path = dir.path;
                      final isSelected =
                          selectionMode && selectedPaths.contains(path);
                      final name = segments.isNotEmpty &&
                              segments.last.isNotEmpty
                          ? segments.last
                          : dir.path;
                      return buildDirectoryTile(dir, path, isSelected, name);
                    }
                    final fileIndex = index - dirs.length;
                    final info = files[fileIndex];
                    final path = info.file.path;
                    final isSelected =
                        selectionMode && selectedPaths.contains(path);
                    return buildFileTile(context, info, path, isSelected);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // add/remove path; exit selection mode when empty
  void applySelectionToggle(String path, bool isSelected) {
    if (isSelected) {
      selectedPaths.remove(path);
      if (selectedPaths.isEmpty) selectionMode = false;
    } else {
      selectedPaths.add(path);
    }
  }

  // wrapper: setState + applySelectionToggle
  void toggleSelectionForPath(String path, bool isSelected) {
    setState(() => applySelectionToggle(path, isSelected));
  }

  // long-press: enter selection mode or toggle item
  void handleSelectionLongPress(String path, bool isSelected) {
    setState(() {
      if (!selectionMode) {
        selectionMode = true;
        selectedPaths..clear()..add(path);
      } else {
        applySelectionToggle(path, isSelected);
      }
    });
  }

  void onDirTap(Directory dir, String path, bool isSelected) {
    if (selectionMode) {
      toggleSelectionForPath(path, isSelected);
    } else {
      setState(() {
        if (currentDirectory != null) {
          directoryStack.add(currentDirectory!);
        }
        currentDirectory = dir;
        reloadDirectory();
      });
    }
  }

  void onDirLongPress(String path, bool isSelected) {
    handleSelectionLongPress(path, isSelected);
  }

  // in selection mode: toggle; else: open CsvViewPage
  void onFileTap(BuildContext context, RecordingFileInfo info, String path,
      bool isSelected, bool inSelectionMode) {
    if (inSelectionMode) {
      toggleSelectionForPath(path, isSelected);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => CsvViewPage(info: info),
        ),
      );
    }
  }

  void onFileLongPress(String path, bool isSelected) {
    handleSelectionLongPress(path, isSelected);
  }

  bool get allSelected {
    final totalItems = currentFiles.length + currentDirectories.length;
    return totalItems > 0 && selectedPaths.length == totalItems;
  }

  bool get hasSelectedFiles =>
      currentFiles.any((f) => selectedPaths.contains(f.file.path));

  // true if any selected dir is session_N
  bool hasSelectedSessionFolders() {
    return currentDirectories.any((d) {
      if (!selectedPaths.contains(d.path)) return false;
      final name = d.path.split(Platform.pathSeparator).last;
      return RegExp(r'^session_\d+$').hasMatch(name);
    });
  }

  // upload enabled only when current dir is dd.mm.yyyy (not root, not inside session)
  bool isAtDateLevel() {
    if (currentDirectory == null) return false;
    final name = currentDirectory!.path.split(Platform.pathSeparator).last;
    return RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(name);
  }

  // select all or clear all; exit selection mode when clearing
  void handleToggleSelectAll() {
    final totalItems = currentFiles.length + currentDirectories.length;
    final allSelected =
        totalItems > 0 && selectedPaths.length == totalItems;
    setState(() {
      if (allSelected) {
        selectedPaths.clear();
        selectionMode = false;
      } else {
        selectionMode = true;
        selectedPaths
          ..clear()
          ..addAll(currentDirectories.map((d) => d.path))
          ..addAll(currentFiles.map((f) => f.file.path));
      }
    });
  }

  // folder tile: tap to navigate or toggle; long-press to select
  Widget buildDirectoryTile(
      Directory dir, String path, bool isSelected, String name) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.folder,
          color: isSelected
              ? AppTheme.accentSecondary
              : AppTheme.accentPrimary,
        ),
        title: Text(name,
            style: const TextStyle(color: AppTheme.textPrimary)),
        subtitle: const Text(
          'Нажмите, чтобы открыть папку',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppTheme.textSecondary),
        onTap: () => onDirTap(dir, path, isSelected),
        onLongPress: () => onDirLongPress(path, isSelected),
      ),
    );
  }

  // file tile: tap to open CsvView or toggle; trailing: upload, share, delete
  Widget buildFileTile(BuildContext context, RecordingFileInfo info,
      String path, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: ListTile(
        leading: Icon(
          isSelected ? Icons.check_circle : Icons.insert_drive_file,
          color: isSelected
              ? AppTheme.accentSecondary
              : AppTheme.accentPrimary,
        ),
        title: Text(info.name,
            style: const TextStyle(color: AppTheme.textPrimary)),
        subtitle: Text(
          'Дата: ${info.formattedModified}   •   Размер: ${info.formattedSize}',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        trailing: selectionMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.cloud_upload,
                        color: AppTheme.textSecondary),
                    tooltip: 'Отправить в полисомнографию',
                    onPressed: () =>
                        showPolysomnographyUploadDialog(context, [info]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share,
                        color: AppTheme.textSecondary),
                    tooltip: 'Поделиться',
                    onPressed: () =>
                        FilesPage.filesController.shareFile(info),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.textSecondary),
                    tooltip: 'Удалить',
                    onPressed: () =>
                        confirmAndDeleteSingle(context, info),
                  ),
                ],
              ),
        onTap: () => onFileTap(context, info, path, isSelected, selectionMode),
        onLongPress: () => onFileLongPress(path, isSelected),
      ),
    );
  }

  // dialog: patient ID/name; upload files; navigate to processed tab on success
  Future<void> showPolysomnographyUploadDialog(
    BuildContext context,
    List<RecordingFileInfo> files,
  ) async {
    final patientIdController = TextEditingController();
    final patientNameController = TextEditingController();

    final result = await showDialog<({int patientId, String patientName})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Отправка в полисомнографию'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Файлов к отправке: ${files.length}'),
                const SizedBox(height: 16),
                TextField(
                  controller: patientIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID пациента *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: patientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя пациента *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final pid =
                    int.tryParse(patientIdController.text.trim());
                final name = patientNameController.text.trim();
                if (pid == null || name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заполните ID и имя пациента'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop((patientId: pid, patientName: name));
              },
              child: const Text('Отправить'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    try {
      for (var i = 0; i < files.length; i++) {
        final info = files[i];
        final path = info.file.path.toLowerCase();
        final isTxt = path.endsWith('.txt');
        await polysomnographyService.uploadPatientFile(
          file: info.file,
          patientId: result.patientId,
          patientName: '${result.patientName}_${i + 1}',
          samplingFrequency: isTxt
              ? PolysomnographyConstants.defaultSamplingFrequencyHz
              : null,
        );
      }

      if (!mounted) return;

      Get.find<PolysomnographyController>()
          .setLastUploadedPatientId(result.patientId);
      Get.find<NavigationController>().changeIndex(3);
      // navigate to processed tab and load patient
      processedFilesPageKey.currentState?.loadPatientById(result.patientId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Загружено файлов: ${files.length}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка отправки: $e')),
      );
    }
  }
}
