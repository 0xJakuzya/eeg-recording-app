// view for displaying the list of devices
// uses ble controller to scan for devices


import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/views/device_details_page.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BleController>(
      init: BleController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Подключение устройства'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            actions: [
              Obx(() {
                final scanning = controller.isScanning.value;
                return IconButton(
                  icon: scanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: scanning ? null : () => controller.scanDevices(),
                  tooltip: 'Обновить устройства',
                );
              }),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 20),
              Obx(() {
                final device = controller.connectedDevice.value;
                if (device == null) {
                  return const SizedBox.shrink();
                }
                final name = device.platformName.trim();
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Подключенное устройство',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          name.isEmpty ? 'Неизвестное устройство' : name,
                        ),
                        subtitle: Text(device.remoteId.str),
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            Get.to(() => DeviceDetailsPage(device: device));
                          },
                          tooltip: 'Характеристики устройства',
                        ),
                        onTap: () async {
                          await controller.disconnect();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Список устройств',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  final connectedId = controller.connectedDevice.value?.remoteId.str;
                  return StreamBuilder<List<ScanResult>>(
                    stream: controller.scanResults,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final devices = snapshot.data!
                            .where((result) =>
                                result.device.platformName.trim().isNotEmpty &&
                                result.device.remoteId.str != connectedId)
                            .toList();
                        if (devices.isEmpty) {
                          return const Center(
                            child: Text('Устройства не найдены'),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final data = devices[index];
                            final name = data.device.platformName.trim();
                            return StreamBuilder<BluetoothConnectionState>(
                              stream: data.device.connectionState,
                              initialData: BluetoothConnectionState.disconnected,
                              builder: (context, snapshot) {
                                final isConnected = (controller.connectedDevice.value?.remoteId.str == data.device.remoteId.str) ||
                                    (snapshot.data == BluetoothConnectionState.connected);
                                return Card(
                                  elevation: 2,
                                  child: ListTile(
                                    title: Text(
                                      name.isEmpty ? 'Неизвестное устройство' : name,
                                    ),
                                    subtitle: Text(data.device.remoteId.str),
                                    trailing: isConnected
                                        ? IconButton(
                                            icon: const Icon(Icons.info_outline),
                                            onPressed: () {
                                              Get.to(() => DeviceDetailsPage(device: data.device));
                                            },
                                            tooltip: 'Характеристики устройства',
                                          )
                                        : null,
                                    // on tap, connect/disconnect to the device
                                    onTap: () async {
                                      if (isConnected) {
                                        // disconnect
                                        await controller.disconnect();
                                      } else {
                                        // connect
                                        await controller.connectToDevices(data.device);
                                      }
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        );
                      } else {
                        return const Center(
                          child: Text('Нажмите кнопку для поиска устройств'),
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