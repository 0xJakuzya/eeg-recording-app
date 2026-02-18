import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// List tile for a BLE characteristic with read/write/notify buttons.
class CharacteristicTile extends StatelessWidget {
  const CharacteristicTile({super.key, required this.characteristic});

  final BluetoothCharacteristic characteristic;

  @override
  Widget build(BuildContext context) {
    final char = characteristic;
    return ListTile(
      title: Text('Characteristic: ${char.uuid}'),
      subtitle: Text('Properties: ${char.properties}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (char.properties.read)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                final value = await char.read();
                debugPrint('Read: $value');
              },
            ),
          if (char.properties.write)
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: () async {
                await char.write([0x01]);
                debugPrint('Written');
              },
            ),
          if (char.properties.notify)
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () async {
                await char.setNotifyValue(true);
                char.lastValueStream
                    .listen((value) => debugPrint('Notification: $value'));
              },
            ),
        ],
      ),
    );
  }
}
