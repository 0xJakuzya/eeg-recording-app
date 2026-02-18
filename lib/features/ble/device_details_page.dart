import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_app/features/ble/ble_controller.dart';
import 'package:ble_app/features/ble/widgets/characteristic_list.dart';

/// Page displaying BLE device services and characteristics.
class DeviceDetailsPage extends StatelessWidget {
  const DeviceDetailsPage({super.key, required this.device});

  final BluetoothDevice device;

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
      body: Obx(() {
        return ListView.builder(
          itemCount: controller.services.length,
          itemBuilder: (context, index) {
            final service = controller.services[index];
            return ExpansionTile(
              title: Text('Service: ${service.uuid}'),
              subtitle:
                  Text('${service.characteristics.length} characteristics'),
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
