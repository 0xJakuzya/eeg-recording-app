import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// list tile for a ble characteristic with read/write/notify buttons
class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;

  const CharacteristicTile({super.key, required this.characteristic});

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
                var value = await char.read();
                print('Read: $value');
              },
            ),
          if (char.properties.write)
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: () async {
                await char.write([0x01]);
                print('Written');
              },
            ),
          if (char.properties.notify)
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () async {
                await char.setNotifyValue(true);
                char.lastValueStream.listen((value) => print('Notification: $value'));
              },
            ),
        ],
      ),
    );
  }
}
