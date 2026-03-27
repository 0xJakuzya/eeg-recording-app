import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io' show Platform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/constants/ble_constants.dart';

// controller for BLE scan, connect, disconnect; auto-selects first notify/indicate characteristic for EEG data
class BleController extends GetxController {
  // connected device; services; auto-selected data char; scan/connection state
  final Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  final RxList<BluetoothService> services = <BluetoothService>[].obs;
  final Rx<String?> selectedDataServiceUuid = Rx<String?>(null);
  final Rx<String?> selectedDataCharUuid = Rx<String?>(null);
  final RxBool isScanning = false.obs;
  DateTime? lastScanAt;
  final Rx<BluetoothConnectionState> connectionState =
      BluetoothConnectionState.disconnected.obs;
  StreamSubscription<BluetoothConnectionState>? connectionSub;

  @override
  void onReady() {
    // start scan on controller ready
    super.onReady();
    scanDevices();
  }

  // throttled by minScanInterval; optional service filter for targeted scan
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

  // live stream of BLE scan results
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  // disconnect current if different; connect; discover services; auto-select data char; listen for disconnect
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

    // cancel previous listener to avoid stale callbacks
    await connectionSub?.cancel();
    connectionSub = device.connectionState.listen((state) {
      connectionState.value = state;
      if (state == BluetoothConnectionState.disconnected) {
        connectedDevice.value = null;
        clearSelection();
        services.clear();
      }
    });
    connectionState.value = BluetoothConnectionState.connected;
  }

  // prefers services not in skipServiceParts; for EEG Headset prefers FFF1 (response) for data stream
  void autoSelectDataCharacteristic(
      List<BluetoothService> discoveredServices) {
    selectedDataServiceUuid.value = null;
    selectedDataCharUuid.value = null;

    bool matchesResponseUuid(String uuid) {
      final lower = uuid.toLowerCase();
      return lower == 'fff1' ||
          lower == BleConstants.responseCharUuid.toLowerCase();
    }

    bool pickFrom(Iterable<BluetoothService> servicesToSearch) {
      for (final service in servicesToSearch) {
        // Prefer FFF1 (response) for EEG data stream
        for (final c in service.characteristics) {
          if ((c.properties.notify || c.properties.indicate) &&
              matchesResponseUuid(c.uuid.str)) {
            selectedDataServiceUuid.value = service.uuid.str;
            selectedDataCharUuid.value = c.uuid.str;
            print('[EEG] BLE: selected FFF1 (response) for data stream');
            dev.log('BLE: selected data char FFF1 (response) for EEG stream',
                name: 'BleController');
            return true;
          }
        }
        // Fallback: first notify/indicate
        for (final c in service.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            selectedDataServiceUuid.value = service.uuid.str;
            selectedDataCharUuid.value = c.uuid.str;
            print('[EEG] BLE: selected ${c.uuid.str} (FFF1 not found)');
            dev.log('BLE: selected data char ${c.uuid.str} (FFF1 not found)',
                name: 'BleController');
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

  // reset selected data service/characteristic UUIDs
  void clearSelection() {
    selectedDataServiceUuid.value = null;
    selectedDataCharUuid.value = null;
  }

  // eeg_device command char (uuid fff2)
  BluetoothCharacteristic? get commandCharacteristic {
    for (final service in services) {
      for (final c in service.characteristics) {
        final lower = c.uuid.str.toLowerCase();
        if (lower == 'fff2' ||
            lower == BleConstants.commandCharUuid.toLowerCase()) {
          return c;
        }
      }
    }
    return null;
  }

  // AT config channel characteristic (uuid fff3)
  BluetoothCharacteristic? get configCharacteristic {
    for (final service in services) {
      for (final c in service.characteristics) {
        final lower = c.uuid.str.toLowerCase();
        if (lower == 'fff3' ||
            lower == BleConstants.configCharUuid.toLowerCase()) {
          return c;
        }
      }
    }
    return null;
  }

  // first characteristic with write or writeWithoutResponse
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

  // characteristic by selectedDataServiceUuid/selectedDataCharUuid; used for notify stream
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

  // appends ; if missing; prefers command char, else first writable
  Future<bool> sendCommand(String command) async {
    final char = commandCharacteristic ?? writableCharacteristic;
    if (char == null) return false;
    if (connectionState.value != BluetoothConnectionState.connected) {
      return false;
    }
    try {
      var cmd = command.trim();
      if (!cmd.endsWith(';')) cmd = '$cmd;';
      if (char.properties.write) {
        await char.write(cmd.codeUnits);
      } else if (char.properties.writeWithoutResponse) {
        await char.write(cmd.codeUnits, withoutResponse: true);
      } else {
        return false;
      }
      return true;
    } catch (ignored) {
      return false;
    }
  }

  // sends AT command as raw bytes; NO semicolon appended
  // prefers fff3, falls back to fff2, then first writable
  Future<bool> sendAtCommand(String command) async {
    final char = configCharacteristic ?? commandCharacteristic ?? writableCharacteristic;
    if (char == null) return false;
    if (connectionState.value != BluetoothConnectionState.connected) return false;
    try {
      final bytes = command.trim().codeUnits;
      if (char.properties.write) {
        await char.write(bytes);
      } else if (char.properties.writeWithoutResponse) {
        await char.write(bytes, withoutResponse: true);
      } else {
        return false;
      }
      return true;
    } catch (ignored) {
      return false;
    }
  }

  // sends command multiple times — device sometimes ignores first attempts
  Future<bool> sendCommandWithRetry(
    String command, {
    int attempts = BleConstants.commandRetryAttempts,
    Duration delay = BleConstants.commandRetryDelay,
  }) async {
    for (int i = 0; i < attempts; i++) {
      final ok = await sendCommand(command);
      if (!ok) return false;
      if (i < attempts - 1) await Future.delayed(delay);
    }
    return true;
  }

  // sends cmdOff, disables notify, disconnects; clears state on done
  Future<void> disconnect() async {
    final device = connectedDevice.value;
    if (device == null) return;

    final writeChar = commandCharacteristic ?? writableCharacteristic;
    if (writeChar != null) {
      try {
        await writeChar.write(BleConstants.cmdOff.codeUnits);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (ignored) {}
    }

    final characteristic = selectedDataCharacteristic;
    if (characteristic != null) {
      try {
        await characteristic.setNotifyValue(false);
      } catch (ignored) {}
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
