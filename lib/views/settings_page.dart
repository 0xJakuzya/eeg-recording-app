import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/utils/extension.dart';
import 'package:ble_app/widgets/device_control_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Настройки',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Запись',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
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
                const Divider(height: 0),
                // rotation interval selection
                Obx(() {
                  final minutes =
                      settingsController.rotationIntervalMinutes.value;
                  String subtitle;
                  if (minutes <= 1) {
                    subtitle = 'Каждую минуту';
                  } else if (minutes < 60) {
                    subtitle = 'Каждые $minutes мин';
                  } else {
                    final hours = (minutes / 60).round();
                    subtitle = 'Каждые $hours ч';
                  }

                  final options = <int>[1, 5, 10, 15, 30, 60];

                  return ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Размер файла записи'),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final selected = await showModalBottomSheet<int>(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (ctx) {
                          return SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Text(
                                    'Интервал разбиения файлов',
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final value in options)
                                    ListTile(
                                      title: Text(
                                        value < 60
                                            ? '$value минут'
                                            : '${(value / 60).round()} часов',
                                      ),
                                      onTap: () => Navigator.pop(ctx, value),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                      if (selected != null) {
                        await settingsController
                            .setRotationIntervalMinutes(selected);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Устройство',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          DeviceControlSection(settingsController: settingsController),
          const SizedBox(height: 8),
          Card(
            child: Obx(() {
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
                title: const Text('Формат данных ЭЭГ'),
                subtitle: Text(subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final selected = await showModalBottomSheet<DataFormat>(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (ctx) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Text(
                                'Формат данных устройства',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              ListTile(
                                title: const Text('int8'),
                                onTap: () =>
                                    Navigator.pop(ctx, DataFormat.int8),
                              ),
                              ListTile(
                                title: const Text('int12'),
                                onTap: () =>
                                    Navigator.pop(ctx, DataFormat.uint12Le),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                  if (selected != null) {
                    await settingsController.setDataFormat(selected);
                  }
                },
              );
            }),
          ),
          const SizedBox(height: 24),
          Text(
            'Информация',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('О приложении'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'EEG Recording App',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text(
                      'Приложение для записи ЭЭГ данных с BLE устройств.',
                    ),
                    const SizedBox(height: 8),
                    const Text('Поддержка 1-8 каналов.'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}