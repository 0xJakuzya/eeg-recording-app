import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/controllers/recording_controller.dart';
import 'package:ble_app/views/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  Get.put(SettingsController());
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: WithForegroundTask(child: const MainNavigation()),
    );
  }
}
