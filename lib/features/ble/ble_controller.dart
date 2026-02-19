import 'dart:developer' as dev;
import 'dart:io' show Platform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/constants/ble_constants.dart';

/// Controller for Bluetooth Low Energy operations.
/// Handles scanning, connecting, and disconnecting from devices.
class BleController extends GetxController {
  final Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  final RxList<BluetoothService> services = <BluetoothService>[].obs;
  final Rx<String?> selectedDataServiceUuid = Rx<String?>(null);
  final Rx<String?> selectedDataCharUuid = Rx<String?>(null);
  final RxBool isScanning = false.obs;
  DateTime? lastScanAt;
  final Rx<BluetoothConnectionState> connectionState =
      BluetoothConnectionState.disconnected.obs;

  @override
  void onReady() {
    super.onReady();
    scanDevices();
  }

  Future<void> scanDevices({String? serviceUuid}) async {
    if (isScanning.value) return;
    final now = DateTime.now();
    if (lastScanAt != null &&
        now.difference(lastScanAt!) < BleConstants.minScanInterval) {
      return;
    }
    isScanning.value = true;
    try {
      lastScanAt = now;
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
      isScanning.value = false;
    }
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

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

    if (Platform.isAndroid) {
      try {
        final mtu = await device.requestMtu(BleConstants.requestMtuSize);
        if (mtu > 0) dev.log('BLE MTU negotiated: $mtu', name: 'BleController');
      } catch (ignored) {}
    }

    final discoveredServices = await device.discoverServices();
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

  void autoSelectDataCharacteristic(
      List<BluetoothService> discoveredServices) {
    selectedDataServiceUuid.value = null;
    selectedDataCharUuid.value = null;

    bool pickFrom(Iterable<BluetoothService> servicesToSearch) {
      for (final service in servicesToSearch) {
        for (final c in service.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            selectedDataServiceUuid.value = service.uuid.str;
            selectedDataCharUuid.value = c.uuid.str;
            return true;
          }
        }
      }
      return false;
    }
    final preferredServices = discoveredServices.where((service) {
      final su = service.uuid.str.toLowerCase();
      return !BleConstants.skipServiceParts.any((p) => su.contains(p));
    });
    if (pickFrom(preferredServices)) return;
    pickFrom(discoveredServices);
  }

  void clearSelection() {
    selectedDataServiceUuid.value = null;
    selectedDataCharUuid.value = null;
  }
<<<<<<< HEAD:lib/controllers/ble_controller.dart
  BluetoothCharacteristic? get writableCharacteristic {
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          return c;
        }
      }
    }
    return null;
  }

  /// Command characteristic for EEG_Device (UUID fff2)
=======

>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/ble/ble_controller.dart
  BluetoothCharacteristic? get commandCharacteristic {
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.uuid.str.toLowerCase() ==
            BleConstants.commandCharUuid.toLowerCase()) {
          return c;
        }
      }
    }
    return null;
  }

<<<<<<< HEAD:lib/controllers/ble_controller.dart
  /// Sends a command to the EEG device. Commands must end with ";"
=======
  BluetoothCharacteristic? get writableCharacteristic {
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          return c;
        }
      }
    }
    return null;
  }

>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/ble/ble_controller.dart
  Future<bool> sendCommand(String command) async {
    final char = commandCharacteristic ?? writableCharacteristic;
    if (char == null) return false;
    if (connectionState.value != BluetoothConnectionState.connected) {
      return false;
    }
    try {
      var cmd = command.trim();
      if (!cmd.endsWith(';')) cmd = '$cmd;';
<<<<<<< HEAD:lib/controllers/ble_controller.dart
      await char.write(cmd.codeUnits);
      return true;
    } catch (_) {
=======
      if (char.properties.write) {
        await char.write(cmd.codeUnits);
      } else if (char.properties.writeWithoutResponse) {
        await char.write(cmd.codeUnits, withoutResponse: true);
      } else {
        return false;
      }
      return true;
    } catch (ignored) {
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/ble/ble_controller.dart
      return false;
    }
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

  Future<void> disconnect() async {
    final device = connectedDevice.value;
    if (device == null) return;

    final writeChar = commandCharacteristic ?? writableCharacteristic;
    if (writeChar != null) {
      try {
<<<<<<< HEAD:lib/controllers/ble_controller.dart
        await writeChar.write('off;'.codeUnits);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {}
=======
        await writeChar.write(BleConstants.cmdOff.codeUnits);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (ignored) {}
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/ble/ble_controller.dart
    }

    final characteristic = selectedDataCharacteristic;
    if (characteristic != null) {
      try {
        await characteristic.setNotifyValue(false);
<<<<<<< HEAD:lib/controllers/ble_controller.dart
      } catch (_) {}
=======
      } catch (ignored) {}
>>>>>>> 7f305aa641e8c919b719f0e405e79f64a8d73166:lib/features/ble/ble_controller.dart
    }

    connectionState.value = BluetoothConnectionState.disconnecting;
    try {
      await device.disconnect();
      clearSelection();
      services.clear();
    } finally {
      connectedDevice.value = null;
      connectionState.value = BluetoothConnectionState.disconnected;
    }
  }
}
