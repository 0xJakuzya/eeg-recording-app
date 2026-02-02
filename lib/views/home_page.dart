import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_app/controllers/ble_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<BleController>(
        init: BleController(),
        builder: (controller) {
          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 180,
                  color: Colors.blue,
                  child: Center(child: const Text(
                    'EEG App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () => controller.scanDevices(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(350, 55),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    child: const Text(
                      'Scan Devices',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<ScanResult>>(
                  stream: controller.scanResults,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final filteredDevices = snapshot.data!.where((result) => result.device.remoteId.str == '50:32:5F:BE:1D:D0').toList();
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredDevices.length,
                        itemBuilder: (context, index) {
                          final data = filteredDevices[index];
                          final name = data.device.platformName.trim();
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              title: Text(
                                name.isEmpty ? 'Неизвестное устройство' : name,
                              ),
                              subtitle: Text(data.device.remoteId.str),
                              onTap: () => controller.connectToDevices(data.device),
                            ),
                          );
                        },
                      );
                    } else {
                      return const Center(child: Text('No devices found'));
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}