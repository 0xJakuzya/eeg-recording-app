import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/core/app_theme.dart';
import 'package:ble_app/views/device_details_page.dart';
import 'package:ble_app/widgets/device_list.dart';

// view for displaying the list of bluetooth devices
// shows connected device and available devices from scan results.
// allows connecting and disconnecting from devices using ble controller.
class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BleController>(
      init: BleController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Подключение устройства',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            actions: [
              Obx(() {
                final state = controller.connectionState.value;
                final color = switch (state) {
                  BluetoothConnectionState.connected => AppTheme.statusConnected,
                  BluetoothConnectionState.connecting => Colors.amber,
                  BluetoothConnectionState.disconnecting => Colors.amber,
                  BluetoothConnectionState.disconnected => AppTheme.textMuted,
                };
                return Tooltip(
                  message: switch (state) {
                    BluetoothConnectionState.connected => 'Подключено',
                    BluetoothConnectionState.connecting => 'Подключение...',
                    BluetoothConnectionState.disconnecting => 'Отключение...',
                    BluetoothConnectionState.disconnected => 'Не подключено',
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, left: 16),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: state == BluetoothConnectionState.connected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
              Obx(() {
                final scanning = controller.isScanning.value;
                return IconButton(
                  icon: scanning
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.statusConnected,
                            ),
                          ),
                        )
                      : Icon(Icons.refresh, color: AppTheme.textPrimary),
                  onPressed: scanning ? null : () => controller.scanDevices(),
                  tooltip: 'Обновить устройства',
                );
              }),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 8),
              const SizedBox(height: 20),
              Obx(() {
                final device = controller.connectedDevice.value;
                if (device == null) return const SizedBox.shrink();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Подключенное устройство',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.statusConnected.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.statusConnected.withValues(alpha: 0.12),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.bluetooth_connected,
                            color: AppTheme.statusConnected,
                          ),
                          title: Text(
                            DeviceListTile.displayName(device),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            device.remoteId.str,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          onTap: () => Get.to(
                            () => DeviceDetailsPage(device: device),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.info_outline, color: AppTheme.textSecondary),
                                tooltip: 'Характеристики устройства',
                                onPressed: () => Get.to(
                                  () => DeviceDetailsPage(device: device),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.statusFailed,
                                  foregroundColor: AppTheme.textPrimary,
                                ),
                                onPressed: () => controller.disconnect(),
                                icon: const Icon(Icons.link_off),
                                label: const Text('Отключить'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Список устройств',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // devices list from scan results
              Expanded(
                child: Obx(() {
                  final connectedId = controller.connectedDevice.value?.remoteId.str;
                  return StreamBuilder<List<ScanResult>>(
                    stream: controller.scanResults,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        // filter out devices without names and already connected device
                        final devices = snapshot.data!
                            .where((result) =>
                                result.device.platformName.trim().isNotEmpty &&
                                result.device.remoteId.str != connectedId)
                            .toList();
                        if (devices.isEmpty) {
                          return Center(
                            child: Text(
                              'Устройства не найдены',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final data = devices[index];
                            // listen to connection state changes
                            return StreamBuilder<BluetoothConnectionState>(
                              stream: data.device.connectionState,
                              initialData: BluetoothConnectionState.disconnected,
                              builder: (context, snapshot) {
                                final isConnected = (controller.connectedDevice.value?.remoteId.str == data.device.remoteId.str) ||
                                    (snapshot.data == BluetoothConnectionState.connected);
                                return DeviceListTile(
                                  device: data.device,
                                  isConnected: isConnected,
                                  onTap: () async {
                                    // по тапу только подключаемся
                                    if (!isConnected) {
                                      await controller.connectToDevices(data.device);
                                    }
                                  },
                                  onDetailsPressed: isConnected
                                      ? () => Get.to(() => DeviceDetailsPage(device: data.device))
                                      : null,
                                );
                              },
                            );
                          },
                        );
                      } else {
                        return Center(
                          child: Text(
                            'Нажмите кнопку для поиска устройств',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        );
                      }
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}