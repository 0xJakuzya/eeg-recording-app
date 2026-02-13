import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
   import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/core/recording_constants.dart';
import 'package:ble_app/utils/extension.dart';

class _DeviceControlSection extends StatelessWidget {
  const _DeviceControlSection({
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final bleController = Get.find<BleController>();
    return Obx(() {
      final isConnected =
          bleController.connectionState.value == BluetoothConnectionState.connected;
      final samplingRate = settingsController.samplingRateHz.value;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isConnected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Подключите устройство для управления',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isConnected) const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.speed),
              title: const Text('Частота дискретизации'),
              subtitle: Text('$samplingRate Гц'),
              trailing: const Icon(Icons.chevron_right),
              onTap: isConnected
                  ? () async {
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
                                    'Частота дискретизации',
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  for (final hz
                                      in RecordingConstants.supportedSamplingRates)
                                    ListTile(
                                      title: Text('$hz Гц'),
                                      onTap: () => Navigator.pop(ctx, hz),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                      if (selected != null) {
                        await settingsController.setSamplingRateHz(selected);
                      }
                    }
                  : null,
            ),
            if (isConnected) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ok =
                            await settingsController.applySamplingRateToDevice();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Частота ${settingsController.samplingRateHz.value} Гц применена'
                                  : 'Не удалось отправить команду'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Применить'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await settingsController.sendPing();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Команда ping отправлена'
                                  : 'Не удалось отправить команду'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.wifi_tethering),
                      label: const Text('Ping'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      onPressed: () async {
                        final ok =
                            await settingsController.sendStartTransmission();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Передача данных запущена'
                                  : 'Не удалось отправить команду'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Старт'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: () async {
                        final ok =
                            await settingsController.sendStopTransmission();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Передача данных остановлена'
                                  : 'Не удалось отправить команду'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('Стоп'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

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
          Card(
            child: Column(
              children: [
                Obx(() {
                  final format = settingsController.dataFormat.value;
                  String subtitle;
                  switch (format) {
                    case DataFormat.int8:
                      subtitle = 'int8 (-128..127)';
                      break;
                    case DataFormat.eeg24BitVolt:
                      subtitle = '24‑бит, вольты';
                      break;
                    default:
                      subtitle = format.name;
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
                                    subtitle: const Text('(-128..127)'),
                                    onTap: () =>
                                        Navigator.pop(ctx, DataFormat.int8),
                                  ),
                                  ListTile(
                                    title: const Text('24‑бит вольты'),
                                    subtitle: const Text(
                                      '24‑бит коды → вольты',
                                    ),
                                    onTap: () =>
                                        Navigator.pop(ctx, DataFormat.eeg24BitVolt),
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
                const Divider(height: 0),
                _DeviceControlSection(settingsController: settingsController),
              ],
            ),
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