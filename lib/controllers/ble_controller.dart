import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/ble_constants.dart';

// controller for bluetooth low energy operations
// handles scanning, connecting, and disconnecting from devices.
// uses flutter_blue_plus for bluetooth operations and getx for state management.
class BleController extends GetxController {

  Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  RxList<BluetoothService> services = <BluetoothService>[].obs;
  Rx<String?> selectedDataServiceUuid = Rx<String?>(null);
  Rx<String?> selectedDataCharUuid = Rx<String?>(null);

  RxBool isScanning = false.obs;
  DateTime? lastScanAt; 

  /// Текущий статус BLE‑подключения
  Rx<BluetoothConnectionState> connectionState =
      BluetoothConnectionState.disconnected.obs;

  @override
  void onReady() {
    super.onReady();
    scanDevices();
  }

  // scan devices
  Future<void> scanDevices({String? serviceUuid}) async {

    if (isScanning.value) return;
    final now = DateTime.now();
    if (lastScanAt != null && now.difference(lastScanAt!) < BleConstants.minScanInterval) {
      return;
    }
    // start scanning
    isScanning.value = true;
    try {
      lastScanAt = DateTime.now();
      await FlutterBluePlus.stopScan(); 
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
    final current = connectedDevice.value;
    if (current != null && current.remoteId.str != device.remoteId.str) {
      await current.disconnect();
      connectedDevice.value = null;
      services.clear();
    }
    connectionState.value = BluetoothConnectionState.connecting;
    await device.connect(
      license: License.free,
      timeout: BleConstants.connectTimeout,
    );
    connectedDevice.value = device;
    // discover services
    final List<BluetoothService> discoveredServices = await device.discoverServices();
    services.value = discoveredServices;
    autoSelectDataCharacteristic(discoveredServices);
    device.connectionState.listen((state) {
      connectionState.value = state;
      if (state == BluetoothConnectionState.disconnected) {
        connectedDevice.value = null;
        clearSelection();
        services.clear();
      }
    });
    connectionState.value = BluetoothConnectionState.connected;
  }
  void autoSelectDataCharacteristic(List<BluetoothService> discoveredServices) {
    selectedDataServiceUuid.value = null;
    selectedDataCharUuid.value = null;
    const skipServiceParts = ['180f', '180a', '1800', '1801']; // battery, device info, etc
    for (final service in discoveredServices) {
      final su = service.uuid.str.toLowerCase();
      if (skipServiceParts.any((p) => su.contains(p))) continue;
      for (final c in service.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          selectedDataServiceUuid.value = service.uuid.str;
          selectedDataCharUuid.value = c.uuid.str;
          return;
        }
      }
    }
    for (final service in discoveredServices) {
      for (final c in service.characteristics) {
        if (c.properties.notify || c.properties.indicate) {
          selectedDataServiceUuid.value = service.uuid.str;
          selectedDataCharUuid.value = c.uuid.str;
          return;
        }
      }
    }
  }
  void clearSelection() {
    selectedDataServiceUuid.value = null;
    selectedDataCharUuid.value = null;
  }
  BluetoothCharacteristic? get selectedDataCharacteristic {
    final sUuid = selectedDataServiceUuid.value;
    final cUuid = selectedDataCharUuid.value;
    if (sUuid == null || cUuid == null) return null;
    for (final service in services) {
      if (service.uuid.str != sUuid) continue;
      for (final c in service.characteristics) {
        if (c.uuid.str == cUuid) return c;
      }
    }
    return null;
  }
  // disconnect
  Future<void> disconnect() async {
    if (connectedDevice.value != null) {
      connectionState.value = BluetoothConnectionState.disconnecting;
      await connectedDevice.value!.disconnect();
      connectedDevice.value = null;
      clearSelection();
      services.clear();
      connectionState.value = BluetoothConnectionState.disconnected;
    }
  }
}