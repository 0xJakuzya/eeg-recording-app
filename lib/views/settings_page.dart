import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/core/data_format.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const Divider(),
          // recording directory
          Obx(() {
            final path = settingsController.recordingDirectory.value;
            return ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Папка для записей'),
              subtitle: Text(
                path != null && path.isNotEmpty
                    ? path
                    : 'По умолчанию (документы приложения)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final dir = await FilePicker.platform.getDirectoryPath();
                if (dir != null) {
                  await settingsController.setRecordingDirectory(dir);
                }
              },
            );
          }),

          // data format selection
          const Divider(),
          Obx(() {
            final format = settingsController.dataFormat.value;
            String subtitle;
            switch (format) {
              case DataFormat.int8:
                subtitle = 'int8 (-128..127)';
                break;
              case DataFormat.uint12Le:
                subtitle = 'int12 (0..4095)';
                break;
            }

            return ListTile(
              leading: const Icon(Icons.memory),
              title: const Text('Формат данных устройства'),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final selected = await showModalBottomSheet<DataFormat>(
                  context: context,
                  builder: (ctx) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('int8'),
                          onTap: () => Navigator.pop(ctx, DataFormat.int8),
                        ),
                        ListTile(
                          title: const Text('int12'),
                          onTap: () => Navigator.pop(ctx, DataFormat.uint12Le),
                        ),
                      ],
                    );
                  },
                );
                if (selected != null) {
                  await settingsController.setDataFormat(selected);
                }
              },
            );
          }),

          // about application
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('О приложении'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'EEG Recording App',
                applicationVersion: '1.0.0',
                children: [
                  const Text('Приложение для записи ЭЭГ данных с BLE устройств.'),
                  const SizedBox(height: 8),
                  const Text('Поддержка 1-8 каналов.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}