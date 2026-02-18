import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_app/core/app_theme.dart';

/// Card with device name, id, optional details button, and onTap.
/// Dark theme with accent when connected.
class DeviceListTile extends StatelessWidget {
  const DeviceListTile({
    super.key,
    required this.device,
    required this.isConnected,
    required this.onTap,
    this.onDetailsPressed,
  });

  final BluetoothDevice device;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback? onDetailsPressed;

  static String displayName(BluetoothDevice device) {
    final name = device.platformName.trim();
    return name.isEmpty ? 'Неизвестное устройство' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? AppTheme.statusConnected.withValues(alpha: 0.5)
              : AppTheme.borderSubtle,
          width: isConnected ? 1.5 : 1,
        ),
        boxShadow: isConnected
            ? [
                BoxShadow(
                  color: AppTheme.statusConnected.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: isConnected ? AppTheme.statusConnected : AppTheme.textMuted,
          size: 24,
        ),
        title: Text(
          displayName(device),
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: isConnected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          device.remoteId.str,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: onDetailsPressed != null
            ? IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: onDetailsPressed,
                tooltip: 'Характеристики устройства',
                color: AppTheme.textSecondary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
