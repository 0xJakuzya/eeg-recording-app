import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/core/app_theme.dart';
import 'package:ble_app/core/polysomnography_constants.dart';
import 'package:ble_app/models/recording_models.dart';
import 'package:ble_app/services/polysomnography_service.dart';
import 'package:ble_app/views/csv_view_page.dart';
import 'package:ble_app/widgets/files_selection_bar.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  static const FilesController filesController = FilesController();

  @override
  State<FilesPage> createState() => FilesPageState();
}

class FilesPageState extends State<FilesPage> {
  late Future<RecordingDirectoryContent> directoryFuture;
  final Set<String> selectedPaths = <String>{};
  List<RecordingFileInfo> currentFiles = <RecordingFileInfo>[];
  List<Directory> currentDirectories = <Directory>[];
  bool selectionMode = false;
  Directory? currentDirectory;
  final List<Directory> directoryStack = <Directory>[];
  final PolysomnographyApiService polysomnographyService =
      PolysomnographyApiService(
    baseUrl: PolysomnographyConstants.defaultBaseUrl,
  );

  @override
  void initState() {
    super.initState();
    reloadDirectory();
  }

  void reloadDirectory() {
    selectedPaths.clear();
    selectionMode = false;
    directoryFuture = FilesPage.filesController.listDirectory(directory: currentDirectory);
  }

  void refreshFiles() {
    setState(() {
      currentDirectory = null;
      directoryStack.clear();
      reloadDirectory();
    });
  }

  void goUpDirectory() {
    if (directoryStack.isEmpty) return;
    setState(() {
      currentDirectory = directoryStack.removeLast();
      reloadDirectory();
    });
  }

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
              onPressed: directoryStack.isEmpty
                  ? null
                  : () {
                      goUpDirectory();
                    },
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
            onPressed: () {
              refreshFiles();
            },
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
              onUploadSelected: _hasSelectedSessionFolders() || _isAtDateLevel()
                  ? null
                  : () async {
                      final selectedFileInfos = currentFiles
                          .where((f) => selectedPaths.contains(f.file.path))
                          .toList();
                      if (selectedFileInfos.isEmpty) return;
                      await showPolysomnographyUploadDialog(
                        context,
                        selectedFileInfos,
                      );
                    },
              onDeleteSelected: () async {
                final toDeleteFiles = currentFiles
                    .where((f) => selectedPaths.contains(f.file.path))
                    .toList();
                final toDeleteDirs = currentDirectories
                    .where((d) => selectedPaths.contains(d.path))
                    .toList();
                if (toDeleteFiles.isEmpty && toDeleteDirs.isEmpty) {
                  return;
                }

                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Удалить файлы'),
                        content: Text(
                            'Удалить выбранные объекты (${toDeleteFiles.length + toDeleteDirs.length})?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true),
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
              },
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
          if (content == null) {
            return const SizedBox.shrink();
          }
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
                      final segments =
                          dir.path.split(Platform.pathSeparator);
                      final path = dir.path;
                      final isSelected =
                          selectionMode && selectedPaths.contains(path);
                      final name =
                          segments.isNotEmpty && segments.last.isNotEmpty
                              ? segments.last
                              : dir.path;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
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
                          title: Text(name, style: const TextStyle(color: AppTheme.textPrimary)),
                          subtitle: const Text(
                            'Нажмите, чтобы открыть папку',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                          onTap: () {
                            if (selectionMode) {
                              setState(() {
                                if (isSelected) {
                                  selectedPaths.remove(path);
                                  if (selectedPaths.isEmpty) {
                                    selectionMode = false;
                                  }
                                } else {
                                  selectedPaths.add(path);
                                }
                              });
                            } else {
                              setState(() {
                                if (currentDirectory != null) {
                                  directoryStack.add(currentDirectory!);
                                }
                                currentDirectory = dir;
                                reloadDirectory();
                              });
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              if (!selectionMode) {
                                selectionMode = true;
                                selectedPaths
                                  ..clear()
                                  ..add(path);
                              } else {
                                if (isSelected) {
                                  selectedPaths.remove(path);
                                  if (selectedPaths.isEmpty) {
                                    selectionMode = false;
                                  }
                                } else {
                                  selectedPaths.add(path);
                                }
                              }
                            });
                          },
                        ),
                      );
                    }

                    final fileIndex = index - dirs.length;
                    final info = files[fileIndex];
                    final path = info.file.path;
                    final isSelected =
                        selectionMode && selectedPaths.contains(path);
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.insert_drive_file,
                          color: isSelected
                              ? AppTheme.accentSecondary
                              : AppTheme.accentPrimary,
                        ),
                        title: Text(info.name, style: const TextStyle(color: AppTheme.textPrimary)),
                        subtitle: Text(
                          'Дата: ${info.formattedModified}   •   Размер: ${info.formattedSize}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        trailing: selectionMode
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.share, color: AppTheme.textSecondary),
                                onPressed: () => FilesPage
                                    .filesController
                                    .shareFile(info),
                              ),
                        onTap: () {
                          if (selectionMode) {
                            setState(() {
                              if (isSelected) {
                                selectedPaths.remove(path);
                                if (selectedPaths.isEmpty) {
                                  selectionMode = false;
                                }
                              } else {
                                selectedPaths.add(path);
                              }
                            });
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    CsvViewPage(info: info),
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            if (!selectionMode) {
                              selectionMode = true;
                              selectedPaths
                                ..clear()
                                ..add(path);
                            } else {
                              if (isSelected) {
                                selectedPaths.remove(path);
                                if (selectedPaths.isEmpty) {
                                  selectionMode = false;
                                }
                              } else {
                                selectedPaths.add(path);
                              }
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool get allSelected {
    final totalItems = currentFiles.length + currentDirectories.length;
    return totalItems > 0 && selectedPaths.length == totalItems;
  }

  bool get hasSelectedFiles {
    return currentFiles.any((f) => selectedPaths.contains(f.file.path));
  }

  bool _hasSelectedSessionFolders() {
    return currentDirectories.any((d) {
      if (!selectedPaths.contains(d.path)) return false;
      final name = d.path.split(Platform.pathSeparator).last;
      return RegExp(r'^session_\d+$').hasMatch(name);
    });
  }

  bool _isAtDateLevel() {
    if (currentDirectory == null) return false;
    final name = currentDirectory!.path.split(Platform.pathSeparator).last;
    return RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(name);
  }

  void handleToggleSelectAll() {
    final totalItems = currentFiles.length + currentDirectories.length;
    final allSelected = totalItems > 0 && selectedPaths.length == totalItems;
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

  Future<void> showPolysomnographyUploadDialog(
    BuildContext context,
    List<RecordingFileInfo> files,
  ) async {
    const int patientId = PolysomnographyConstants.defaultPatientId;
    const double samplingFrequency =
        PolysomnographyConstants.defaultSamplingFrequencyHz;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Отправка в полисомнографию'),
            content: Text(
              'Отправить ${files.length} файл(ов)?\n'
              'patient_id=$patientId, частота ${samplingFrequency.toInt()} Гц',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Отправить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final uploadedAll = <String>[];

      for (var i = 0; i < files.length; i++) {
        final info = files[i];
        final parentName = info.file.parent.path
            .split(Platform.pathSeparator)
            .last;
        final sessionId = RegExp(r'^session_\d+$').hasMatch(parentName)
            ? parentName
            : 'files';
        final patientName =
            PolysomnographyConstants.storageKey(sessionId, i + 1);

        await polysomnographyService.uploadTxtFile(
          file: info.file,
          patientId: patientId,
          patientName: patientName,
          samplingFrequency: samplingFrequency,
        );

        uploadedAll.add(info.file.path);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Отправлено файлов: ${files.length}\n'
            'Файлы: ${uploadedAll.join(', ')}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки: $e'),
        ),
      );
    }
  }
}