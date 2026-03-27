import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/features/polysomnography/polysomnography_service.dart';
import 'package:ble_app/features/settings/settings_controller.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/core/constants/ble_constants.dart';
import 'package:ble_app/core/constants/polysomnography_constants.dart';

// recording, ble, polysomnography settings; bottom sheets for pickers
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();

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
                icon: Icons.speed,
                title: 'Частота дискретизации',
                subtitle: Obx(() {
                  final hz = settings.recordingSamplingRateHz.value;
                  return Text('$hz Гц');
                }),
                onTap: () => showSamplingRateSheet(context, settings),
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

  static Future<void> handlePolysomnographyCheck(
      BuildContext ctx, String url) async {
    if (url.isEmpty) return;
    final svc = PolysomnographyApiService(baseUrl: url);
    final err = await svc.checkConnection(url);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(err == null ? 'Подключение успешно' : 'Ошибка: $err'),
          backgroundColor: err == null ? Colors.green : null,
        ),
      );
    }
  }

  static Future<void> handlePolysomnographyReset(
      BuildContext ctx, SettingsController settings) async {
    await settings.setPolysomnographyBaseUrl(null);
    if (ctx.mounted) Navigator.pop(ctx);
  }

  static Future<void> handlePolysomnographySave(
      BuildContext ctx,
      TextEditingController textController,
      SettingsController settings) async {
    await settings.setPolysomnographyBaseUrl(textController.text);
    if (ctx.mounted) Navigator.pop(ctx);
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => handlePolysomnographyCheck(ctx, controller.text),
            child: const Text('Проверить'),
          ),
          TextButton(
            onPressed: () => handlePolysomnographyReset(ctx, settings),
            child: const Text('Сбросить'),
          ),
          FilledButton(
            onPressed: () =>
                handlePolysomnographySave(ctx, controller, settings),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((timestamp) {
      controller.dispose();
    });
  }

  Future<void> showSamplingRateSheet(
      BuildContext context, SettingsController settings) async {
    final selected = await showPicker<int>(
      context,
      title: 'Частота дискретизации',
      items: BleConstants.availableSampleRates
          .map((hz) => PickerItem(hz, '$hz Гц'))
          .toList(),
    );
    if (selected != null) await settings.setSamplingRate(selected);
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
        const Text('Запись ЭЭГ с одноканального BLE устройства.'),
      ],
    );
  }
}

// value/label pair for bottom sheet picker
class PickerItem<T> {
  final T value;
  final String label;
  PickerItem(this.value, this.label);
}

// section title in settings list
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

// card container with dividers between children
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

// single row: icon, title, subtitle, optional tap
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

