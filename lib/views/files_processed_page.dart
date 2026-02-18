import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/polysomnography_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/core/app_theme.dart';
import 'package:ble_app/core/polysomnography_constants.dart';
import 'package:ble_app/services/polysomnography_service.dart';
import 'package:ble_app/views/session_details_page.dart';

enum FileProcessStatus { pending, inProgress, done, failed }

class FileProcessState {
  const FileProcessState({
    required this.status,
    this.result,
    this.sleepGraphIndex,
    this.error,
  });
  final FileProcessStatus status;
  final PredictResult? result;
  final int? sleepGraphIndex;
  final String? error;
}

class FilesProcessedPage extends StatefulWidget {
  const FilesProcessedPage({super.key});

  @override
  State<FilesProcessedPage> createState() => FilesProcessedPageState();
}

class FilesProcessedPageState extends State<FilesProcessedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  PolysomnographyApiService get polysomnographyService =>
      PolysomnographyApiService(
        baseUrlGetter: () =>
            Get.find<SettingsController>().effectivePolysomnographyBaseUrl,
      );

  final TextEditingController patientIdController = TextEditingController();
  List<PatientFileInfo> files = [];
  bool isLoading = false;
  String? loadError;
  int? lastUploadedPatientId;
  int? _currentPatientId;
  final Map<int, FileProcessState> _fileStates = {};
  final Map<int, Map<int, FileProcessState>> _patientCache = {};

  void loadPatientById(int? patientId) {
    if (patientId != null) {
      patientIdController.text = patientId.toString();
      _loadFiles();
    }
  }

  void setLastUploadedPatientId(int id) {
    lastUploadedPatientId = id;
    loadPatientById(id);
  }

  Future<void> _loadFiles() async {
    final raw = patientIdController.text.trim();
    final patientId = int.tryParse(raw);
    if (patientId == null) {
      setState(() {
        files = [];
        _fileStates.clear();
        loadError = 'Введите корректный ID пациента';
      });
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
      if (_currentPatientId != null && _fileStates.isNotEmpty) {
        _patientCache[_currentPatientId!] = Map.from(_fileStates);
      }
      _fileStates.clear();
    });

    try {
      final list = await polysomnographyService.getPatientFilesList(patientId);
      if (!mounted) return;

      final cached = _patientCache[patientId];
      for (final f in list) {
        final existing = cached?[f.index];
        if (existing != null && (existing.status == FileProcessStatus.done || existing.status == FileProcessStatus.failed)) {
          _fileStates[f.index] = existing;
        } else {
          _fileStates[f.index] = const FileProcessState(status: FileProcessStatus.pending);
        }
      }

      setState(() {
        files = list;
        isLoading = false;
        loadError = null;
        _currentPatientId = patientId;
      });

      _processAllFiles(patientId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        files = [];
        isLoading = false;
        loadError = 'Ошибка: $e';
      });
    }
  }

  Future<void> _processAllFiles(int patientId) async {
    for (final file in files) {
      if (!mounted) return;
      if (_fileStates[file.index]?.status == FileProcessStatus.done) continue;

      setState(() {
        _fileStates[file.index] = const FileProcessState(status: FileProcessStatus.inProgress);
      });

      try {
        final result = await polysomnographyService.savePredictJson(
          patientId: patientId,
          fileIndex: file.index,
          channel: file.isEdf ? PolysomnographyConstants.preferredEdfChannel : null,
        );

        if (!mounted) return;
        final controller = Get.find<PolysomnographyController>();
        final sleepGraphIndex = controller.takeNextSleepGraphIndex();

        final state = FileProcessState(
          status: FileProcessStatus.done,
          result: result,
          sleepGraphIndex: sleepGraphIndex,
        );
        setState(() {
          _fileStates[file.index] = state;
          _patientCache[patientId] ??= {};
          _patientCache[patientId]![file.index] = state;
        });
      } catch (e) {
        if (!mounted) return;
        final state = FileProcessState(
          status: FileProcessStatus.failed,
          error: e.toString(),
        );
        setState(() {
          _fileStates[file.index] = state;
          _patientCache[patientId] ??= {};
          _patientCache[patientId]![file.index] = state;
        });
      }
    }
  }

  Future<void> _retryFile(PatientFileInfo file) async {
    final patientId = int.tryParse(patientIdController.text.trim());
    if (patientId == null) return;

    setState(() {
      _fileStates[file.index] = const FileProcessState(status: FileProcessStatus.inProgress);
    });

    try {
      final result = await polysomnographyService.savePredictJson(
        patientId: patientId,
        fileIndex: file.index,
        channel: file.isEdf ? PolysomnographyConstants.preferredEdfChannel : null,
      );

      if (!mounted) return;
      final controller = Get.find<PolysomnographyController>();
      final sleepGraphIndex = controller.takeNextSleepGraphIndex();

      final state = FileProcessState(
        status: FileProcessStatus.done,
        result: result,
        sleepGraphIndex: sleepGraphIndex,
      );
      setState(() {
        _fileStates[file.index] = state;
        _patientCache[patientId] ??= {};
        _patientCache[patientId]![file.index] = state;
      });
    } catch (e) {
      if (!mounted) return;
      final state = FileProcessState(
        status: FileProcessStatus.failed,
        error: e.toString(),
      );
      setState(() {
        _fileStates[file.index] = state;
        _patientCache[patientId] ??= {};
        _patientCache[patientId]![file.index] = state;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _onFileTap(PatientFileInfo file) async {
    final state = _fileStates[file.index];

    if (state?.status == FileProcessStatus.done && state?.result != null) {
      await _openDetails(file, state!);
      return;
    }

    if (state?.status == FileProcessStatus.failed) {
      await _retryFile(file);
    }
  }

  Future<void> _openDetails(PatientFileInfo file, FileProcessState state) async {
    final result = state.result!;
    final patientId = int.tryParse(patientIdController.text.trim());
    final sleepGraphIndex = state.sleepGraphIndex ?? result.jsonIndex ?? file.index;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionDetailsPage(
          fileName: file.name,
          prediction: result.prediction,
          jsonIndex: sleepGraphIndex,
          service: polysomnographyService,
          patientId: patientId,
          fileIndex: file.index,
        ),
      ),
    );
  }

  void refreshSessions() {
    final polysomnographyController = Get.find<PolysomnographyController>();
    final pendingId = polysomnographyController.lastUploadedPatientId.value;
    if (pendingId != null) {
      polysomnographyController.clearLastUploadedPatientId();
      loadPatientById(pendingId);
    }
  }

  String _statusLabel(FileProcessStatus status) {
    switch (status) {
      case FileProcessStatus.pending:
        return 'В очереди автообработки';
      case FileProcessStatus.inProgress:
        return 'Автообработка...';
      case FileProcessStatus.done:
        return 'Готово ✓';
      case FileProcessStatus.failed:
        return 'Ошибка. Нажмите для повтора';
    }
  }

  Widget _statusWidget(FileProcessStatus status) {
    switch (status) {
      case FileProcessStatus.pending:
        return Icon(Icons.schedule, color: AppTheme.textMuted, size: 24);
      case FileProcessStatus.inProgress:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case FileProcessStatus.done:
        return Icon(Icons.check_circle, color: AppTheme.statusPredictionReady, size: 28);
      case FileProcessStatus.failed:
        return Icon(Icons.error_outline, color: AppTheme.statusFailed, size: 28);
    }
  }

  @override
  void dispose() {
    patientIdController.dispose();
    super.dispose();
  }

  bool get _isProcessing => _fileStates.values
      .any((s) => s.status == FileProcessStatus.inProgress || s.status == FileProcessStatus.pending);

  int get _doneCount =>
      _fileStates.values.where((s) => s.status == FileProcessStatus.done).length;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isProcessing && files.isNotEmpty
              ? 'Обработка файлов ($_doneCount/${files.length})'
              : 'Обработка файлов',
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: patientIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID пациента',
                      hintText: 'Введите ID',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _loadFiles(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: isLoading ? null : () => _loadFiles(),
                  child: isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Загрузить'),
                ),
              ],
            ),
          ),
          if (loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                loadError!,
                style: const TextStyle(color: AppTheme.statusFailed),
              ),
            ),
          Expanded(
            child: _buildFilesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    if (files.isEmpty && !isLoading) {
      return Center(
        child: Text(
          'Введите ID пациента и нажмите «Загрузить» для просмотра файлов',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final state = _fileStates[file.index] ?? const FileProcessState(status: FileProcessStatus.pending);
        final canTap = state.status == FileProcessStatus.done || state.status == FileProcessStatus.failed;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: canTap ? () => _onFileTap(file) : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: state.status == FileProcessStatus.done
                      ? AppTheme.statusPredictionReady.withValues(alpha: 0.4)
                      : AppTheme.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    file.isEdf ? Icons.medical_information : Icons.insert_drive_file,
                    color: AppTheme.accentPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Индекс файла: ${file.index}  •  sleep_graph: ${state.sleepGraphIndex ?? "—"}  •  ${_statusLabel(state.status)}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusWidget(state.status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
