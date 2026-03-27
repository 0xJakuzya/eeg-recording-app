import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:ble_app/features/ble/ble_controller.dart';
import 'package:ble_app/features/files/files_controller.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/features/recording/recording_controller.dart';
import 'package:ble_app/features/recording/eeg_foreground_service.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/features/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await stopOrphanedForegroundServiceIfNeeded();
  // order: settings first (others depend), then files, ble, recording
  Get.put(SettingsController());
  Get.put(FilesController());
  Get.put(BleController());
  Get.put(RecordingController());
  runApp(const MyApp());
}

// root app with GetX DI, dark theme, foreground task wrapper for recording
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'EEG Recording App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: WithForegroundTask(child: const MainNavigation()),
    );
  }
}
