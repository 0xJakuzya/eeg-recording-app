import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/features/polysomnography/polysomnography_controller.dart';
import 'package:ble_app/features/polysomnography/polysomnography_service.dart';
import 'package:ble_app/features/polysomnography/session_details_page.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/core/constants/polysomnography_constants.dart';

final GlobalKey<ProcessedFilesPageState> processedFilesPageKey =
    GlobalKey<ProcessedFilesPageState>();

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

class ProcessedFilesPage extends StatefulWidget {
  const ProcessedFilesPage({super.key});

  @override
  State<ProcessedFilesPage> createState() => ProcessedFilesPageState();
}

class ProcessedFilesPageState extends State<ProcessedFilesPage>
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
  int? currentPatientId;
  final Map<int, FileProcessState> fileStates = {};
  final Map<int, Map<int, FileProcessState>> patientCache = {};

  void loadPatientById(int? patientId) {
    if (patientId != null) {
      patientIdController.text = patientId.toString();
      loadPatientFiles();
    }
  }

  void setLastUploadedPatientId(int id) {
    lastUploadedPatientId = id;
    loadPatientById(id);
  }

  Future<void> loadPatientFiles() async {
    final raw = patientIdController.text.trim();
    final patientId = int.tryParse(raw);
    if (patientId == null) {
      setState(() {
        files = [];
        fileStates.clear();
        loadError = 'Введите корректный ID пациента';
      });
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
      if (currentPatientId != null && fileStates.isNotEmpty) {
        patientCache[currentPatientId!] = Map.from(fileStates);
      }
      fileStates.clear();
    });

    try {
      final list = await polysomnographyService.getPatientFilesList(patientId);
      if (!mounted) return;

      final cached = patientCache[patientId];
      for (final f in list) {
        final existing = cached?[f.index];
        if (existing != null &&
            (existing.status == FileProcessStatus.done ||
                existing.status == FileProcessStatus.failed)) {
          fileStates[f.index] = existing;
        } else {
          fileStates[f.index] =
              const FileProcessState(status: FileProcessStatus.pending);
        }
      }

      setState(() {
        files = list;
        isLoading = false;
        loadError = null;
        currentPatientId = patientId;
      });

      processAllFiles(patientId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        files = [];
        isLoading = false;
        loadError = 'Ошибка: $e';
      });
    }
  }

  Future<void> processAllFiles(int patientId) async {
    for (final file in files) {
      if (!mounted) return;
      if (fileStates[file.index]?.status == FileProcessStatus.done) continue;

      setState(() {
        fileStates[file.index] =
            const FileProcessState(status: FileProcessStatus.inProgress);
      });

      await runFilePrediction(
        patientId: patientId,
        file: file,
        showErrorSnackBar: false,
      );
    }
  }

  Future<void> retryFile(PatientFileInfo file) async {
    final patientId = int.tryParse(patientIdController.text.trim());
    if (patientId == null) return;

    setState(() {
      fileStates[file.index] =
          const FileProcessState(status: FileProcessStatus.inProgress);
    });

    await runFilePrediction(
      patientId: patientId,
      file: file,
      showErrorSnackBar: true,
    );
  }

  Future<void> runFilePrediction({
    required int patientId,
    required PatientFileInfo file,
    bool showErrorSnackBar = false,
  }) async {
    try {
      final result = await polysomnographyService.savePredictJson(
        patientId: patientId,
        fileIndex: file.index,
        channel:
            file.isEdf ? PolysomnographyConstants.preferredEdfChannel : null,
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
        fileStates[file.index] = state;
        patientCache[patientId] ??= {};
        patientCache[patientId]![file.index] = state;
      });
    } catch (e) {
      if (!mounted) return;
      final state = FileProcessState(
        status: FileProcessStatus.failed,
        error: e.toString(),
      );
      setState(() {
        fileStates[file.index] = state;
        patientCache[patientId] ??= {};
        patientCache[patientId]![file.index] = state;
      });
      if (showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> onFileTap(PatientFileInfo file) async {
    final state = fileStates[file.index];

    if (state?.status == FileProcessStatus.done && state?.result != null) {
      await openDetails(file, state!);
      return;
    }

    if (state?.status == FileProcessStatus.failed) {
      await retryFile(file);
    }
  }

  Future<void> openDetails(
      PatientFileInfo file, FileProcessState state) async {
    final result = state.result!;
    final patientId = int.tryParse(patientIdController.text.trim());
    final sleepGraphIndex =
        state.sleepGraphIndex ?? result.jsonIndex ?? file.index;

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

  String getStatusLabel(FileProcessStatus status) {
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

  Widget buildStatusWidget(FileProcessStatus status) {
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
        return Icon(Icons.check_circle,
            color: AppTheme.statusPredictionReady, size: 28);
      case FileProcessStatus.failed:
        return Icon(Icons.error_outline, color: AppTheme.statusFailed, size: 28);
    }
  }

  @override
  void dispose() {
    patientIdController.dispose();
    super.dispose();
  }

  bool get isProcessing => fileStates.values.any((s) =>
      s.status == FileProcessStatus.inProgress ||
      s.status == FileProcessStatus.pending);

  int get doneCount =>
      fileStates.values.where((s) => s.status == FileProcessStatus.done).length;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isProcessing && files.isNotEmpty
              ? 'Обработка файлов ($doneCount/${files.length})'
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
                    onSubmitted: (_) => loadPatientFiles(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: isLoading ? null : () => loadPatientFiles(),
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
            child: buildFilesList(),
          ),
        ],
      ),
    );
  }

  Widget buildFilesList() {
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
        final state =
            fileStates[file.index] ??
                const FileProcessState(status: FileProcessStatus.pending);
        final canTap =
            state.status == FileProcessStatus.done ||
            state.status == FileProcessStatus.failed;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: canTap ? () => onFileTap(file) : null,
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
                    file.isEdf
                        ? Icons.medical_information
                        : Icons.insert_drive_file,
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
                          'Индекс файла: ${file.index}  •  sleep_graph: ${state.sleepGraphIndex ?? "—"}  •  ${getStatusLabel(state.status)}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  buildStatusWidget(state.status),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
