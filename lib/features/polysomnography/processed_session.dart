import 'dart:io';

// overall session processing state
enum ProcessingStatus {
  pending,
  processing,
  done,
  failed,
  unknown,
}

// prediction api state per session
enum PredictionStatus {
  notStarted,
  inProgress,
  done,
  failed,
}

// session model for processed polysomnography dirs
class ProcessedSession {
  final String id;
  final Directory directory;
  final ProcessingStatus status;
  final PredictionStatus predictionStatus;
  final Map<String, dynamic>? prediction;
  final int? jsonIndex;

  const ProcessedSession({
    required this.id,
    required this.directory,
    this.status = ProcessingStatus.unknown,
    this.predictionStatus = PredictionStatus.notStarted,
    this.prediction,
    this.jsonIndex,
  });

  String get path => directory.path;

  // immutable update; null params keep existing values
  ProcessedSession copyWith({
    ProcessingStatus? status,
    PredictionStatus? predictionStatus,
    Map<String, dynamic>? prediction,
    int? jsonIndex,
  }) {
    return ProcessedSession(
      id: id,
      directory: directory,
      status: status ?? this.status,
      predictionStatus: predictionStatus ?? this.predictionStatus,
      prediction: prediction ?? this.prediction,
      jsonIndex: jsonIndex ?? this.jsonIndex,
    );
  }

  // id from last path segment; jsonIndex from session_N pattern
  factory ProcessedSession.fromDirectory(
    Directory directory, {
    ProcessingStatus status = ProcessingStatus.unknown,
  }) {
    final segments = directory.path.split(Platform.pathSeparator);
    final id = segments.isNotEmpty ? segments.last : directory.path;
    int? jsonIndex;
    final match = RegExp(r'session_(\d+)$').firstMatch(id);
    if (match != null) {
      jsonIndex = int.tryParse(match.group(1)!);
    }

    return ProcessedSession(
      id: id,
      directory: directory,
      status: status,
      predictionStatus: PredictionStatus.notStarted,
      jsonIndex: jsonIndex,
    );
  }

  @override
  String toString() =>
      'ProcessedSession(id: $id, path: ${directory.path}, status: $status, predictionStatus: $predictionStatus, jsonIndex: $jsonIndex)';
}
