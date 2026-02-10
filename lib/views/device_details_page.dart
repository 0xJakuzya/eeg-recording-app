import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ble_app/controllers/ble_controller.dart';
import 'package:ble_app/widgets/characteristic_tile.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// view for displaying the details of a connected device
// shows the list of services and characteristics
// uses ble controller to get the list of services and characteristics
class DeviceDetailsPage extends StatelessWidget {
  final BluetoothDevice device;
  const DeviceDetailsPage({super.key, required this.device});
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Устройство: ${controller.connectedDevice.value?.platformName}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
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
              children: service.characteristics
                  .map((char) => CharacteristicTile(characteristic: char))
                  .toList(),
            );
          },
        );
      }),
    );
  }
}