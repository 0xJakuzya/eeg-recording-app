// view for displaying the list of devices
// uses ble controller to scan for devices
// filters devices by mac address

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/views/device_details_page.dart';

class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<BleController>(
        init: BleController(),
        builder: (controller) {
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 180,
                  color: Colors.blue,
                  child: Center(child: const Text(
                    'BLE Devices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),),
                ),
                const SizedBox(height: 20),
                Center(
                  // button for scanning devices
                  child: ElevatedButton(
                    onPressed: () => controller.scanDevices(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(350, 55),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    child: const Text(
                      'Сканировать устройства',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<ScanResult>>(
                  stream: controller.scanResults,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      // filter devices by mac address
                      final filteredDevices = snapshot.data!.where((result) => result.device.remoteId.str == '50:32:5F:BE:1D:D0').toList(); // kraken device
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredDevices.length,
                        itemBuilder: (context, index) {
                          final data = filteredDevices[index];
                          final name = data.device.platformName.trim();
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                name.isEmpty ? 'Неизвестное устройство' : name,
                              ),
                              subtitle: Text(data.device.remoteId.str),
                              trailing: Obx(() {
                                final isConnected = controller.connectedDevice.value?.remoteId.str == data.device.remoteId.str;
                                // button for connecting/disconnecting to the device
                                return ElevatedButton(
                                  onPressed: () async {
                                    if (isConnected) {
                                      // disconnect 
                                      await controller.disconnect();
                                    } else {
                                      // connect 
                                      await controller.connectToDevices(data.device);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected ? Colors.red : Colors.grey,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    isConnected ? 'Отключить' : 'Подключить',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }),
                              // on tap, connect to the device and go to device details page
                              onTap: () async {
                                final isConnected = controller.connectedDevice.value?.remoteId.str == data.device.remoteId.str;
                                if (!isConnected) {
                                  await controller.connectToDevices(data.device);
                                }
                                Get.to(() => DeviceDetailsPage(device: data.device));
                              },
                            ),
                          );
                        },
                      );
                    } else {
                      return const Center(
                        child: Text('Нажимет кнопку для поиска устройств')
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}