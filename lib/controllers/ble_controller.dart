// controller for bluetooth operations
// handles scanning, connecting, and disconnecting from devices
// uses flutter_blue_plus for bluetooth operations

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

// controller for bluetooth operations
class BleController extends GetxController {

  Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  RxList<BluetoothService> services = <BluetoothService>[].obs;

  // scan devices
  Future<void> scanDevices({String? serviceUuid}) async {
    if (serviceUuid != null) {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5), withServices: [Guid(serviceUuid)]);
    } else {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    }
  }

  // get scan results
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  // connect to device
  Future<void> connectToDevices(BluetoothDevice device) async {
    print(device.toString());

    await device.connect(
      license: License.free,
      timeout: const Duration(seconds: 5),
    );

    connectedDevice.value = device;
    
    List<BluetoothService> discoveredServices = await device.discoverServices();
    services.value = discoveredServices;

    // print services and characteristics in terminal
    for (var service in discoveredServices) {
      print('Service UUID: ${service.uuid}');
      for (var characteristic in service.characteristics) {
        print('Characteristic UUID: ${characteristic.uuid}');
        print('Characteristic properties: ${characteristic.properties}');
      }
    }

    // print device connection state in terminal
    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connecting) {
        print('Device ${device.platformName} connecting...');
      } else if (state == BluetoothConnectionState.connected) {
        print('Device connected ${device.platformName}');
      } else {
        print('Device disconnected');
        connectedDevice.value = null;
        services.clear();
      }
    });
  }

  // disconnect 
  Future<void> disconnect() async {
    if (connectedDevice.value != null) {
      await connectedDevice.value!.disconnect();
      connectedDevice.value = null;
      services.clear();
    }
  }
}