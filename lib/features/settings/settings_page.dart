import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/features/ble/ble_controller.dart';
import 'package:ble_app/features/polysomnography/polysomnography_service.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/core/constants/polysomnography_constants.dart';
import 'package:ble_app/core/utils/format_extensions.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    final ble = Get.find<BleController>();

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          SettingsSectionHeader(title: 'Запись'),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.insert_drive_file_outlined,
                title: 'Формат файла',
                subtitle: Obx(() {
                  final ext = settings.recordingFileExtension.value;
                  return Text(ext == '.csv' ? 'CSV' : 'TXT');
                }),
                onTap: () => showFileFormatSheet(context, settings),
              ),
              SettingsTile(
                icon: Icons.tune,
                title: 'Количество каналов для записи',
                subtitle: Obx(() =>
                    Text('${settings.recordingChannelCount.value} каналов')),
                onTap: () => showRecordingChannelCountSheet(context, settings),
              ),
              SettingsTile(
                icon: Icons.folder_outlined,
                title: 'Папка для записей',
                subtitle: Obx(() {
                  final path = settings.recordingDirectory.value;
                  return Text(
                    path != null && path.isNotEmpty ? path : 'По умолчанию',
                  );
                }),
                onTap: () async {
                  final dir = await FilePicker.platform.getDirectoryPath();
                  if (dir != null) await settings.setRecordingDirectory(dir);
                },
              ),
              SettingsTile(
                icon: Icons.schedule,
                title: 'Интервал разбиения',
                subtitle: Obx(() {
                  final m = settings.rotationIntervalMinutes.value;
                  return Text(
                    m <= 1
                        ? 'Каждую минуту'
                        : m < 60
                            ? 'Каждые $m мин'
                            : 'Каждые ${(m / 60).round()} ч',
                  );
                }),
                onTap: () => showRotationSheet(context, settings),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSectionHeader(title: 'Bluetooth'),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.speed,
                title: 'Частота дискретизации',
                subtitle: Obx(() => Text('${settings.samplingRateHz.value} Гц')),
                onTap: () => showSamplingRateSheet(context, settings),
              ),
              SettingsTile(
                icon: Icons.memory,
                title: 'Формат данных',
                subtitle:
                    Obx(() => Text(getDataFormatLabel(settings.dataFormat.value))),
                onTap: () => showDataFormatSheet(context, settings),
              ),
              Obx(() {
                final connected = ble.connectionState.value ==
                    BluetoothConnectionState.connected;
                return DeviceCommandsTile(
                    connected: connected, settings: settings);
              }),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSectionHeader(title: 'Полисомнография'),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Адрес сервера',
                subtitle: Obx(() {
                  final url = settings.polysomnographyBaseUrl.value;
                  return Text(
                    url != null && url.isNotEmpty
                        ? url
                        : 'По умолчанию (${PolysomnographyConstants.defaultBaseUrl})',
                  );
                }),
                onTap: () => showPolysomnographyUrlDialog(context, settings),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSectionHeader(title: 'О приложении'),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.info_outline,
                title: 'EEG Recording App',
                subtitle: const Text('Версия 1.0.0'),
                onTap: () => showAbout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String getDataFormatLabel(DataFormat f) {
    return switch (f) {
      DataFormat.int24Be => 'int24 BE (8 каналов)',
    };
  }

  Future<void> showSamplingRateSheet(
      BuildContext context, SettingsController settings) async {
    const options = [100, 250, 500];
    final selected = await showPicker<int>(
      context,
      title: 'Частота дискретизации',
      items: options.map((v) => PickerItem(v, '$v Гц')).toList(),
    );
    if (selected != null) await settings.setSamplingRate(selected);
  }

  Future<void> showRotationSheet(
      BuildContext context, SettingsController settings) async {
    const options = [1, 5, 10, 15, 30, 60];
    final selected = await showPicker<int>(
      context,
      title: 'Интервал разбиения',
      items: options
          .map((v) => PickerItem(
                v,
                v < 60 ? '$v мин' : '${(v / 60).round()} ч',
              ))
          .toList(),
    );
    if (selected != null) await settings.setRotationIntervalMinutes(selected);
  }

  Future<void> showPolysomnographyUrlDialog(
      BuildContext context, SettingsController settings) async {
    final controller = TextEditingController(
      text: settings.polysomnographyBaseUrl.value ??
          PolysomnographyConstants.defaultBaseUrl,
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Адрес сервера полисомнографии'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://192.168.0.173:8000',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Телефон и ПК с Docker должны быть в одной Wi‑Fi. Узнать IP ПК: ipconfig (Windows), ifconfig (Linux/Mac).',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              final svc = PolysomnographyApiService(baseUrl: url);
              final err = await svc.checkConnection(url);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(err == null
                        ? 'Подключение успешно'
                        : 'Ошибка: $err'),
                    backgroundColor: err == null ? Colors.green : null,
                  ),
                );
              }
            },
            child: const Text('Проверить'),
          ),
          TextButton(
            onPressed: () async {
              await settings.setPolysomnographyBaseUrl(null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сбросить'),
          ),
          FilledButton(
            onPressed: () async {
              await settings.setPolysomnographyBaseUrl(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  Future<void> showDataFormatSheet(
      BuildContext context, SettingsController settings) async {
    final selected = await showPicker<DataFormat>(
      context,
      title: 'Формат данных',
      items: [
        PickerItem(DataFormat.int24Be, 'int24 BE (8 каналов)'),
      ],
    );
    if (selected != null) await settings.setDataFormat(selected);
  }

  Future<void> showFileFormatSheet(
      BuildContext context, SettingsController settings) async {
    final selected = await showPicker<String>(
      context,
      title: 'Формат файла',
      items: [
        PickerItem('.txt', 'TXT'),
        PickerItem('.csv', 'CSV'),
      ],
    );
    if (selected != null) await settings.setRecordingFileExtension(selected);
  }

  Future<void> showRecordingChannelCountSheet(
      BuildContext context, SettingsController settings) async {
    final selected = await showPicker<int>(
      context,
      title: 'Количество каналов для записи',
      items: List.generate(
        8,
        (i) => PickerItem(i + 1, '${i + 1} каналов'),
      ),
    );
    if (selected != null) await settings.setRecordingChannelCount(selected);
  }

  Future<T?> showPicker<T>(
    BuildContext context, {
    required String title,
    required List<PickerItem<T>> items,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppTheme.backgroundSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.label,
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, item.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'EEG Recording App',
      applicationVersion: '1.0.0',
      children: [
        const Text('Запись ЭЭГ с BLE устройств. Поддержка 1–8 каналов.'),
      ],
    );
  }
}

class PickerItem<T> {
  final T value;
  final String label;
  PickerItem(this.value, this.label);
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final list = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        list.add(const Divider(height: 1, indent: 52, endIndent: 16));
      }
      list.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle, width: 1),
      ),
      child: Column(children: list),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final Widget subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, size: 22, color: AppTheme.textSecondary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: DefaultTextStyle(
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        child: subtitle,
      ),
      trailing: onTap != null
          ? Icon(Icons.chevron_right, size: 20, color: AppTheme.textMuted)
          : null,
      onTap: onTap,
    );
  }
}

class DeviceCommandsTile extends StatelessWidget {
  const DeviceCommandsTile({
    super.key,
    required this.connected,
    required this.settings,
  });
  final bool connected;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.bluetooth_disabled, size: 20, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Подключите устройство для команд',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, size: 22, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Text(
                'Команды устройства',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CommandChip(
                icon: Icons.send,
                label: 'Применить частоту',
                onTap: () => runCommand(
                  context,
                  settings.applySamplingRateToDevice(),
                  'Частота применена',
                ),
              ),
              CommandChip(
                icon: Icons.wifi_tethering,
                label: 'Ping',
                onTap: () => runCommand(
                  context,
                  settings.sendPing(),
                  'Ping отправлен',
                ),
              ),
              CommandChip(
                icon: Icons.play_arrow,
                label: 'Старт',
                color: AppTheme.statusPredictionReady,
                onTap: () => runCommand(
                  context,
                  settings.sendStartTransmission(),
                  'Передача запущена',
                ),
              ),
              CommandChip(
                icon: Icons.stop,
                label: 'Стоп',
                color: AppTheme.statusFailed,
                onTap: () => runCommand(
                  context,
                  settings.sendStopTransmission(),
                  'Передача остановлена',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> runCommand(
    BuildContext context,
    Future<bool> future,
    String successMsg,
  ) async {
    final ok = await future;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? successMsg : 'Команда не отправлена'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class CommandChip extends StatelessWidget {
  const CommandChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accentSecondary;
    return Material(
      color: c.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: c,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
