import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/settings_controller.dart';

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
          Obx(() => ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Количество каналов'),
            subtitle: Text('${settingsController.channelCount.value} канал(ов)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showChannelDialog(context, settingsController),
          )),
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Настройки Bluetooth'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // todo: open settings ble
            },
          ),
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Место хранения'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // todo: open storage settings
            },
          ),
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

  void showChannelDialog(BuildContext context, SettingsController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Количество каналов'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsController.channelOptions.map((count) {
            return Obx(() => RadioListTile<int>(
              title: Text('$count канал(ов)'),
              value: count,
              groupValue: controller.channelCount.value,
              onChanged: (value) {
                if (value != null) {
                  controller.setChannelCount(value);
                }
              },
            ));
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
}
