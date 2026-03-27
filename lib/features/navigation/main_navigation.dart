import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/features/navigation/navigation_controller.dart';
import 'package:ble_app/features/polysomnography/polysomnography_controller.dart';
import 'package:ble_app/features/polysomnography/processed_files_page.dart';
import 'package:ble_app/features/ble/connection_page.dart';
import 'package:ble_app/features/recording/recording_page.dart';
import 'package:ble_app/features/files/files_page.dart' show FilesPage, filesPageKey;
import 'package:ble_app/features/settings/settings_page.dart';
import 'package:ble_app/core/theme/app_theme.dart';

// bottom nav with indexed stack; WithForegroundTask wraps body; refresh on tab switch
class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(NavigationController());
    Get.put(PolysomnographyController());
    final controller = Get.find<NavigationController>();
    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: controller.currentIndex.value,
          children: [
            const ConnectionPage(),
            const RecordingPage(),
            FilesPage(key: filesPageKey),
            ProcessedFilesPage(key: processedFilesPageKey),
            const SettingsPage(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: BottomNavigationBar(
            currentIndex: controller.currentIndex.value,
            onTap: (index) {
              controller.changeIndex(index);
              // side effect: refresh when entering files/processed tabs
              if (index == 2) {
                filesPageKey.currentState?.refreshFiles();
              } else if (index == 3) {
                processedFilesPageKey.currentState?.refreshSessions();
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppTheme.backgroundSecondary,
            selectedItemColor: AppTheme.accentSecondary,
            unselectedItemColor: AppTheme.textMuted,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.bluetooth), label: 'Подключение'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.fiber_manual_record), label: 'Запись'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.folder), label: 'Файлы'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.timeline), label: 'Обработка'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings), label: 'Настройки'),
            ],
          ),
        ),
      ),
    );
  }
}
