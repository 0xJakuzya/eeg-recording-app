import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// card with device name, id, optional details button, and onTap
class DeviceListTile extends StatelessWidget {
  final BluetoothDevice device;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback? onDetailsPressed;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.isConnected,
    required this.onTap,
    this.onDetailsPressed,
  });

  static String displayName(BluetoothDevice device) {
    final name = device.platformName.trim();
    return name.isEmpty ? 'Неизвестное устройство' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(displayName(device)),
        subtitle: Text(device.remoteId.str),
        trailing: onDetailsPressed != null
            ? IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: onDetailsPressed,
                tooltip: 'Характеристики устройства',
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
