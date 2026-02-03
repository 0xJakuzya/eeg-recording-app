/// controller for bluetooth low energy operations
/// handles scanning, connecting, and disconnecting from devices.
/// uses flutter_blue_plus for bluetooth operations and getx for state management.

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/ble_constants.dart';

class BleController extends GetxController {

  Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  RxList<BluetoothService> services = <BluetoothService>[].obs; 
  RxBool isScanning = false.obs; 
  DateTime? lastScanAt; 

  @override
  void onReady() {
    super.onReady();
    scanDevices();
  }

  // scan devices
  Future<void> scanDevices({String? serviceUuid}) async {

    if (isScanning.value) return;
    final now = DateTime.now();
    // prevent scanning too frequently
    if (lastScanAt != null && now.difference(lastScanAt!) < BleConstants.minScanInterval) {
      return;
    }
    // start scanning
    isScanning.value = true;
    try {
      lastScanAt = DateTime.now();
      await FlutterBluePlus.stopScan(); // ensure no previous scan is running
      // start scanning with specific service uuid if provided
      if (serviceUuid != null) {
        await FlutterBluePlus.startScan(
          timeout: BleConstants.scanTimeout,
          withServices: [Guid(serviceUuid)],
        );
      } else {
        await FlutterBluePlus.startScan(timeout: BleConstants.scanTimeout);
      }
      await Future.delayed(BleConstants.scanResultsCollectDelay);
    } finally {
      // stop scanning
      isScanning.value = false;
    }
  }

  // get scan results
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  // connect to device
  Future<void> connectToDevices(BluetoothDevice device) async {
    print(device.toString());

    // disconnect from current device if already connected
    final current = connectedDevice.value;
    if (current != null && current.remoteId.str != device.remoteId.str) {
      await current.disconnect();
      connectedDevice.value = null;
      services.clear();
    }

    // connect to device
    await device.connect(
      license: License.free,
      timeout: BleConstants.connectTimeout,
    );

    connectedDevice.value = device;
    
    // discover services
    List<BluetoothService> discoveredServices = await device.discoverServices();
    services.value = discoveredServices;

    // listen for connection state
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