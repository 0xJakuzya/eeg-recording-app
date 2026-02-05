import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/views/device_details_page.dart';
import 'package:ble_app/widgets/device_list_tile.dart';

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
            title: const Text('Подключение устройства'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            actions: [
              // scan button with loading indicator
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
                if (device == null) return const SizedBox.shrink();
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
                    DeviceListTile(
                      device: device,
                      isConnected: true,
                      onTap: () => controller.disconnect(),
                      onDetailsPressed: () => Get.to(() => DeviceDetailsPage(device: device)),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),
              // devices list header
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
                                    if (isConnected) {
                                      await controller.disconnect();
                                    } else {
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
                        // no scan data 
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