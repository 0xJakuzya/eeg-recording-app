import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

import 'package:ble_app/controllers/ble_controller.dart';

// connection status widget
class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Obx(() {
      final BluetoothConnectionState state = controller.connectionState.value;
      final device = controller.connectedDevice.value;

      Color bg;
      Color fg;
      String text;

      if (state == BluetoothConnectionState.connecting) {
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        text = 'Подключение...';
      } else if (state == BluetoothConnectionState.connected) {
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        final name = device?.platformName.trim().isNotEmpty == true
            ? device!.platformName.trim()
            : 'устройству';
        text = 'Подключено к $name';
      } else if (state == BluetoothConnectionState.disconnecting) {
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        text = 'Отключение...';
      } else {
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        text = 'Не подключено';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

