import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ble_app/controllers/files_controller.dart';
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
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
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
              onUploadSelected: () async {
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
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
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

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.folder,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(name),
                          subtitle:
                              const Text('Нажмите, чтобы открыть папку'),
                          trailing: const Icon(Icons.chevron_right),
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
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.insert_drive_file,
                          color:
                              Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(info.name),
                        subtitle: Text(
                          'Дата: ${info.formattedModified}   •   Размер: ${info.formattedSize}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share),
                              onPressed: () => FilesPage
                                  .filesController
                                  .shareFile(info),
                            ),
                          ],
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
    final patientIdController = TextEditingController();
    final patientNameController = TextEditingController();
    const double samplingFrequency =
        PolysomnographyConstants.defaultSamplingFrequencyHz;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Отправка в полисомнографию'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: patientIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID пациента',
                      hintText: 'Например, 1',
                    ),
                  ),
                  TextField(
                    controller: patientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя пациента',
                      hintText: 'patient_name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Частота дискретизации: ${PolysomnographyConstants.defaultSamplingFrequencyHz.toInt()} Гц',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
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

    final idText = patientIdController.text.trim();
    final name = patientNameController.text.trim();

    if (idText.isEmpty || name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    final patientId = int.tryParse(idText);
    if (patientId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный формат ID пациента')),
      );
      return;
    }

    try {
      final uploadedAll = <String>[];

      for (final info in files) {

        await polysomnographyService.uploadTxtFile(
          file: info.file,
          patientId: patientId,
          patientName: name,
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