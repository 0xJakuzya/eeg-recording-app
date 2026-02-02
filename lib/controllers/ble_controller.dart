import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BleController extends GetxController {
  Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  RxList<BluetoothService> services = <BluetoothService>[].obs;

  Future<void> scanDevices({String? serviceUuid}) async {
    if (serviceUuid != null) {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5), withServices: [Guid(serviceUuid)]);
    } else {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    }
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> connectToDevices(BluetoothDevice device) async {
    print(device.toString());

    await device.connect(
      license: License.free,
      timeout: const Duration(seconds: 5),
    );

    connectedDevice.value = device;
    
    List<BluetoothService> discoveredServices = await device.discoverServices();
    services.value = discoveredServices;

    for (var service in discoveredServices) {
      print('Service UUID: ${service.uuid}');
      for (var characteristic in service.characteristics) {
        print('Characteristic UUID: ${characteristic.uuid}');
        print('Characteristic properties: ${characteristic.properties}');
      }
    }

    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connecting) {
        print('Device ${device.platformName} connecting...');
      } else if (state == BluetoothConnectionState.connected) {
        print('Device connected ${device.platformName}');
      } else {
        print('Device disconnected');
      }
    });
  }

  Future<void> disconnect() async {
    if (connectedDevice.value != null) {
      await connectedDevice.value!.disconnect();
      connectedDevice.value = null;
      services.clear();
    }
  }
}