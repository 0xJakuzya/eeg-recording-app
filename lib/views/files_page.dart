import 'package:flutter/material.dart';
import 'package:ble_app/controllers/files_controller.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  static const FilesController filesController = FilesController();

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  late Future<List<RecordingFileInfo>> filesFuture;
  final Set<String> selectedPaths = <String>{};
  List<RecordingFileInfo> currentFiles = <RecordingFileInfo>[];
  bool selectionMode = false;

  @override
  void initState() {
    super.initState();
    reloadFiles();
  }

  void reloadFiles() {
    selectedPaths.clear();
    selectionMode = false;
    filesFuture = FilesPage.filesController.listRecordingFiles();
  }

  Future<void> confirmAndDeleteSingle(
      BuildContext context, RecordingFileInfo info) async {
    final confirmed = await showDialog<bool>(
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

    if (!confirmed) return;

    await FilesPage.filesController.deleteFile(info);

    if (!mounted) return;

    setState(() {
      reloadFiles();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Файл "${info.name}" удалён')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Файлы записи'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить список',
            onPressed: () {
              setState(reloadFiles);
            },
          ),
        ],
      ),
      bottomNavigationBar:
          selectionMode ? buildSelectionBar(context) : null,
      body: FutureBuilder<List<RecordingFileInfo>>(
        future: filesFuture,
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
          final files = snapshot.data ?? <RecordingFileInfo>[];
          currentFiles = files;
          if (files.isEmpty) {
            return const Center(
              child: Text('Записанные файлы не найдены'),
            );
          }

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final info = files[index];
              final path = info.file.path;
              final isSelected =
                  selectionMode && selectedPaths.contains(path);
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.insert_drive_file,
                    color: Colors.blue,
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
                        onPressed: () =>
                            FilesPage.filesController.shareFile(info),
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
          );
        },
      ),
    );
  }

  Widget buildSelectionBar(BuildContext context) {
    final selectedCount = selectedPaths.length;
    final allSelected =
        currentFiles.isNotEmpty && selectedCount == currentFiles.length;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text('Выбрано: $selectedCount'),
            const Spacer(),
            TextButton.icon(
              onPressed: currentFiles.isEmpty
                  ? null
                  : () {
                      setState(() {
                        if (allSelected) {
                          selectedPaths.clear();
                          selectionMode = false;
                        } else {
                          selectionMode = true;
                          selectedPaths
                            ..clear()
                            ..addAll(currentFiles.map((f) => f.file.path));
                        }
                      });
                    },
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
              ),
              label: Text(allSelected ? 'Снять все' : 'Выбрать все'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: selectedCount == 0
                  ? null
                  : () async {
                      final toDelete = currentFiles
                          .where((f) => selectedPaths.contains(f.file.path))
                          .toList();
                      if (toDelete.isEmpty) return;

                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удалить файлы'),
                              content: Text(
                                  'Удалить выбранные файлы (${toDelete.length})?'),
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

                      for (final info in toDelete) {
                        await FilesPage.filesController.deleteFile(info);
                      }

                      if (!mounted) return;

                      setState(() {
                        reloadFiles();
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Удалено файлов: ${toDelete.length}'),
                        ),
                      );
                    },
              icon: const Icon(Icons.delete),
              label: const Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }
}