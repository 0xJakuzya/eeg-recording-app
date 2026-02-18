import 'package:get/get.dart';

/// Controller for polysomnography state.
class PolysomnographyController extends GetxController {
  final lastUploadedPatientId = Rxn<int>();
  int sleepGraphIndexCounter = 0;

  void setLastUploadedPatientId(int id) {
    lastUploadedPatientId.value = id;
  }

  void clearLastUploadedPatientId() {
    lastUploadedPatientId.value = null;
  }

  int takeNextSleepGraphIndex() {
    final index = sleepGraphIndexCounter;
    sleepGraphIndexCounter++;
    return index;
  }
}
