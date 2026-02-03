import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/views/connection_page.dart';
import 'package:ble_app/views/recording_page.dart';
import 'package:ble_app/views/files_page.dart';
import 'package:ble_app/views/settings_page.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController());

    return Obx(() => Scaffold(
      body: IndexedStack(
        index: controller.currentIndex.value,
        children: const [
          ConnectionPage(),
          RecordingPage(),
          FilesPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: controller.currentIndex.value,
        onTap: controller.changeIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: 'Подключение'),
          BottomNavigationBarItem(icon: Icon(Icons.fiber_manual_record), label: 'Запись'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Файлы'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    ));
  }
}

class NavigationController extends GetxController {
  var currentIndex = 0.obs;
  
  void changeIndex(int index) {
    currentIndex.value = index;
  }
}