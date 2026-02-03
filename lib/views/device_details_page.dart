// view for displaying the details of a connected device
// shows the list of services and characteristics
// allows reading and writing to characteristics
// allows subscribing to characteristics

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';


class DeviceDetailsPage extends StatelessWidget {
  final BluetoothDevice device;
  const DeviceDetailsPage({super.key, required this.device});
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Device: ${controller.connectedDevice.value?.platformName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: () {
              controller.disconnect();
              Get.back();
            },
          ),
    
        ],
      ),
      // displaying the list of services and characteristics
      body: Obx(() {
        return ListView.builder(
          itemCount: controller.services.length,
          itemBuilder: (context, index) {
            final service = controller.services[index];
            // list of characteristics for the service
            return ExpansionTile(
              title: Text('Service: ${service.uuid}'),
              subtitle: Text('${service.characteristics.length} characteristics'),
              children: service.characteristics.map((char) {
                // list of properties for the characteristic
                return ListTile(
                  title: Text('Characteristic: ${char.uuid}'),
                  subtitle: Text('Properties: ${char.properties}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (char.properties.read)
                        // button for reading the characteristic
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () async {
                            var value = await char.read();
                            print('Read: $value');
                          },
                        ),
                      if (char.properties.write)
                        // button for writing to the characteristic
                        IconButton(
                          icon: const Icon(Icons.upload),
                          onPressed: () async {
                            await char.write([0x01]);
                            print('Written');
                          },
                        ),
                      if (char.properties.notify)
                        // button for subscribing to the characteristic
                        IconButton(
                          icon: const Icon(Icons.notifications),
                          onPressed: () async {
                            await char.setNotifyValue(true);
                            // listen to the characteristic
                            char.lastValueStream.listen((value) {
                              print('Notification: $value');
                            });
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      }),
    );
  }
}