import 'package:get/get.dart';

/// Контроллер состояния полисомнографии.
class PolysomnographyController extends GetxController {
  final lastUploadedPatientId = Rxn<int>();

  /// Глобальный счётчик для индекса sleep_graph.
  int _sleepGraphIndexCounter = 0;

  void setLastUploadedPatientId(int id) {
    lastUploadedPatientId.value = id;
  }

  void clearLastUploadedPatientId() {
    lastUploadedPatientId.value = null;
  }

  int takeNextSleepGraphIndex() {
    final index = _sleepGraphIndexCounter;
    _sleepGraphIndexCounter++;
    return index;
  }
}
