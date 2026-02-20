import 'package:get/get.dart';

// last uploaded patient id; monotonic index for sleep graph requests
class PolysomnographyController extends GetxController {
  final lastUploadedPatientId = Rxn<int>();
  int sleepGraphIndexCounter = 0;

  // set by upload flow; processed tab reads and clears on refresh
  void setLastUploadedPatientId(int id) {
    lastUploadedPatientId.value = id;
  }

  // called after processed tab loads patient
  void clearLastUploadedPatientId() {
    lastUploadedPatientId.value = null;
  }

  // unique index per file for hypnogram api; increments each call
  int takeNextSleepGraphIndex() {
    final index = sleepGraphIndexCounter;
    sleepGraphIndexCounter++;
    return index;
  }
}
