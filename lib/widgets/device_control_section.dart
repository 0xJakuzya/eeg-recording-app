import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/controllers/settings_controller.dart';
import 'package:ble_app/core/recording_constants.dart';

/// Section for BLE device control: sampling rate, start/stop transmission, ping.
class DeviceControlSection extends StatelessWidget {
  const DeviceControlSection({
    super.key,
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

      return Column(
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
      );
    });
  }
}
