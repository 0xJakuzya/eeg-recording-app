import 'package:get/get.dart';

// holds current bottom nav tab index; 0=ble, 1=recording, 2=files, 3=processed, 4=settings
class NavigationController extends GetxController {
  final currentIndex = 0.obs;

  void changeIndex(int index) {
    currentIndex.value = index;
  }
}
