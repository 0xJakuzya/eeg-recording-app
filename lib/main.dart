import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/files_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/controllers/recording_controller.dart';
import 'package:ble_app/core/app_theme.dart';
import 'package:ble_app/views/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  Get.put(SettingsController());
  Get.put(FilesController());
  Get.put(BleController());
  Get.put(RecordingController());
  runApp(const MyApp());
}

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
