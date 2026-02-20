import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/features/polysomnography/polysomnography_controller.dart';
import 'package:ble_app/features/polysomnography/polysomnography_service.dart';
import 'package:ble_app/features/polysomnography/session_details_page.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/core/constants/polysomnography_constants.dart';

// global key for external access to page state (e.g. load patient from upload flow)
final GlobalKey<ProcessedFilesPageState> processedFilesPageKey =
    GlobalKey<ProcessedFilesPageState>();

// per-file processing state for polysomnography prediction
enum FileProcessStatus { pending, inProgress, done, failed }

// holds result, sleep graph index and error for a single file
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

// page for browsing and processing patient files via polysomnography api
// fetches file list, runs save_predict_json per file, caches results per patient
class ProcessedFilesPage extends StatefulWidget {
  const ProcessedFilesPage({super.key});

  @override
  State<ProcessedFilesPage> createState() => ProcessedFilesPageState();
}

class ProcessedFilesPageState extends State<ProcessedFilesPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // keep state when switching tabs; avoids reload

  // lazy service instance; base url from settings at call time
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
  // cache completed/failed states per patient so switching back restores them
  final Map<int, Map<int, FileProcessState>> patientCache = {};

  void loadPatientById(int? patientId) {
    if (patientId != null) {
      patientIdController.text = patientId.toString();
      loadPatientFiles();
    }
  }

  // called from upload flow; loads patient and updates input
  void setLastUploadedPatientId(int id) {
    lastUploadedPatientId = id;
    loadPatientById(id);
  }

  // validates id, caches current state, fetches list, restores cache, processes all
  Future<void> loadPatientFiles() async {
    final patientId = parsePatientId(patientIdController.text.trim());
    if (patientId == null) {
      setErrorState('Введите корректный ID пациента');
      return;
    }

    cacheCurrentPatientState();
    setLoadingState();

    try {
      final list = await polysomnographyService.getPatientFilesList(patientId);
      if (!mounted) return;

      restoreFileStatesFromCache(list, patientId);

      setState(() {
        files = list;
        isLoading = false;
        loadError = null;
        currentPatientId = patientId;
      });

      processAllFiles(patientId);
    } catch (e) {
      if (!mounted) return;
      setErrorState('Ошибка: $e');
    }
  }

  int? parsePatientId(String raw) => int.tryParse(raw);

  // clears files and fileStates; sets loadError
  void setErrorState(String message) {
    setState(() {
      files = [];
      fileStates.clear();
      isLoading = false;
      loadError = message;
    });
  }

  // clears file states before fresh load
  void setLoadingState() {
    setState(() {
      isLoading = true;
      loadError = null;
      fileStates.clear();
    });
  }

  // saves fileStates to patientCache before switching patient
  void cacheCurrentPatientState() {
    if (currentPatientId != null && fileStates.isNotEmpty) {
      patientCache[currentPatientId!] = Map.from(fileStates);
    }
  }

  // restores done/failed from cache; pending for uncached or new files
  void restoreFileStatesFromCache(List<PatientFileInfo> list, int patientId) {
    final cached = patientCache[patientId];
    for (final f in list) {
      final existing = cached?[f.index];
      if (isCachedResult(existing)) {
        fileStates[f.index] = existing!;
      } else {
        fileStates[f.index] =
            const FileProcessState(status: FileProcessStatus.pending);
      }
    }
  }

  // true if state is done or failed (restorable from cache)
  bool isCachedResult(FileProcessState? state) =>
      state != null &&
      (state.status == FileProcessStatus.done ||
          state.status == FileProcessStatus.failed);

  // processes each file sequentially; skips already done
  Future<void> processAllFiles(int patientId) async {
    for (final file in files) {
      if (!mounted) return;
      if (fileStates[file.index]?.status == FileProcessStatus.done) continue;

      markFileInProgress(file.index);

      await runFilePrediction(
        patientId: patientId,
        file: file,
        showErrorSnackBar: false,
      );
    }
  }

  // updates file state to inProgress; triggers setState
  void markFileInProgress(int fileIndex) {
    setState(() {
      fileStates[fileIndex] =
          const FileProcessState(status: FileProcessStatus.inProgress);
    });
  }

  // re-runs prediction for failed file; shows snackbar on error
  Future<void> retryFile(PatientFileInfo file) async {
    final patientId = parsePatientId(patientIdController.text.trim());
    if (patientId == null) return;

    markFileInProgress(file.index);

    await runFilePrediction(
      patientId: patientId,
      file: file,
      showErrorSnackBar: true,
    );
  }

  // calls save_predict_json; updates state and cache; optional snackbar on error
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
      applySuccessState(patientId, file.index, result);
    } catch (e) {
      if (!mounted) return;
      applyFailureState(patientId, file.index, e.toString());
      if (showErrorSnackBar) {
        this.showErrorSnackBar('Ошибка: $e');
      }
    }
  }

  // assigns sleep graph index from controller; updates fileStates and patientCache
  void applySuccessState(int patientId, int fileIndex, PredictResult result) {
    final controller = Get.find<PolysomnographyController>();
    final sleepGraphIndex = controller.takeNextSleepGraphIndex();

    final state = FileProcessState(
      status: FileProcessStatus.done,
      result: result,
      sleepGraphIndex: sleepGraphIndex,
    );
    updateFileAndCacheState(patientId, fileIndex, state);
  }

  // stores error in state; updates both fileStates and patientCache
  void applyFailureState(int patientId, int fileIndex, String error) {
    final state = FileProcessState(
      status: FileProcessStatus.failed,
      error: error,
    );
    updateFileAndCacheState(patientId, fileIndex, state);
  }

  // atomic update to fileStates and patientCache; triggers rebuild
  void updateFileAndCacheState(
    int patientId,
    int fileIndex,
    FileProcessState state,
  ) {
    setState(() {
      fileStates[fileIndex] = state;
      patientCache[patientId] ??= {};
      patientCache[patientId]![fileIndex] = state;
    });
  }

  // displays error in snackbar; 3 sec duration
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // opens details when done; triggers retry when failed
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

  // navigates to session details with prediction and hypnogram index
  Future<void> openDetails(
      PatientFileInfo file, FileProcessState state) async {
    final result = state.result!;
    final sleepGraphIndex =
        state.sleepGraphIndex ?? result.jsonIndex ?? file.index;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsPage(
          fileName: file.name,
          prediction: result.prediction,
          jsonIndex: sleepGraphIndex,
          service: polysomnographyService,
        ),
      ),
    );
  }

  // called when returning from upload flow; reloads patient if one was just uploaded
  void refreshSessions() {
    final polysomnographyController = Get.find<PolysomnographyController>();
    final pendingId = polysomnographyController.lastUploadedPatientId.value;
    if (pendingId != null) {
      polysomnographyController.clearLastUploadedPatientId();
      loadPatientById(pendingId);
    }
  }

  // localized label per status
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

  // icon or progress indicator per status
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

  // true if any file is pending or in progress
  bool get isProcessing => fileStates.values.any((s) =>
      s.status == FileProcessStatus.inProgress ||
      s.status == FileProcessStatus.pending);

  // count of files with done status
  int get doneCount =>
      fileStates.values.where((s) => s.status == FileProcessStatus.done).length;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(buildAppBarTitle()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPatientInputSection(),
          if (loadError != null) buildErrorBanner(loadError!),
          Expanded(
            child: buildFilesList(),
          ),
        ],
      ),
    );
  }

  // shows progress count when processing
  String buildAppBarTitle() =>
      isProcessing && files.isNotEmpty
          ? 'Обработка файлов ($doneCount/${files.length})'
          : 'Обработка файлов';

  // patient id field and load button
  Widget buildPatientInputSection() {
    return Padding(
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
              onSubmitted: (value) => loadPatientFiles(),
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
    );
  }

  // error text in red below input
  Widget buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.statusFailed),
      ),
    );
  }

  // empty state or list of file rows
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
        return FileListItem(
          file: file,
          state: state,
          getStatusLabel: getStatusLabel,
          buildStatusWidget: buildStatusWidget,
          onTap: () => onFileTap(file),
        );
      },
    );
  }
}

// single file row in list; tap opens session when done, retry when failed
class FileListItem extends StatelessWidget {
  const FileListItem({
    required this.file,
    required this.state,
    required this.getStatusLabel,
    required this.buildStatusWidget,
    required this.onTap,
  });

  final PatientFileInfo file;
  final FileProcessState state;
  final String Function(FileProcessStatus) getStatusLabel;
  final Widget Function(FileProcessStatus) buildStatusWidget;
  final VoidCallback onTap;

  // tap enabled only when done (open) or failed (retry)
  bool get canTap =>
      state.status == FileProcessStatus.done ||
      state.status == FileProcessStatus.failed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canTap ? onTap : null,
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
                      getStatusLabel(state.status),
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
  }
}
