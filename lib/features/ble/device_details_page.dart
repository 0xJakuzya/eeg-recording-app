import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:ble_app/core/theme/app_theme.dart';
import 'package:ble_app/features/ble/ble_controller.dart';
import 'package:ble_app/features/ble/widgets/characteristic_list.dart';

// shows device services/characteristics + AT command terminal for FFF3 (CONFIG_CHANNEL)
class DeviceDetailsPage extends StatefulWidget {
  const DeviceDetailsPage({super.key, required this.device});
  final BluetoothDevice device;

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  late final BleController _controller;
  final List<String> _log = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<int>>? _configSub;
  static const int _maxLogLines = 100;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<BleController>();
    _subscribeToConfig();
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeToConfig() async {
    final char = _controller.configCharacteristic;
    if (char == null) return;
    try {
      await char.setNotifyValue(true);
      _configSub = char.lastValueStream.listen((bytes) {
        if (bytes.isEmpty) return;
        final text = String.fromCharCodes(bytes).trim();
        if (text.isEmpty) return;
        _addLogEntry('← $text');
      });
    } catch (e) {
      _addLogEntry('← [ошибка подписки: $e]');
    }
  }

  void _addLogEntry(String entry) {
    setState(() {
      _log.add(entry);
      if (_log.length > _maxLogLines) {
        _log.removeAt(0);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendAtCommand() async {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty) return;
    _addLogEntry('→ $cmd');
    _inputController.clear();
    final ok = await _controller.sendAtCommand(cmd);
    if (!ok) _addLogEntry('← [ошибка отправки]');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
              'Устройство: ${_controller.connectedDevice.value?.platformName ?? ""}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            )),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: () {
              _controller.disconnect();
              Get.back();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildServicesList()),
          _buildAtTerminal(context),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    return Obx(() {
      return ListView.builder(
        itemCount: _controller.services.length,
        itemBuilder: (context, index) {
          final service = _controller.services[index];
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
    });
  }

  Widget _buildAtTerminal(BuildContext context) {
    final hasConfig = _controller.configCharacteristic != null;
    return ExpansionTile(
      initiallyExpanded: false,
      title: Text(
        'AT-терминал',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        hasConfig ? 'FFF3 доступен' : 'FFF3 не найден',
        style: TextStyle(
          color: hasConfig ? AppTheme.statusConnected : AppTheme.statusWarning,
          fontSize: 12,
        ),
      ),
      children: [
        SizedBox(
          height: 280,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                if (!hasConfig)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.statusWarning, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Характеристика FFF3 не обнаружена. '
                            'Команды будут отправляться через FFF2.',
                            style: TextStyle(
                              color: AppTheme.statusWarning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildLogView()),
                const SizedBox(height: 8),
                _buildCommandInput(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogView() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(8),
      child: _log.isEmpty
          ? const Center(
              child: Text(
                'Лог пуст. Введите AT-команду.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _log.length,
              itemBuilder: (context, index) {
                final line = _log[index];
                final isSent = line.startsWith('→');
                return Text(
                  line,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isSent
                        ? AppTheme.accentViolet
                        : AppTheme.statusConnected,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCommandInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'AT+AUTH=123456',
              hintStyle:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AppTheme.backgroundSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.accentPrimary),
              ),
            ),
            onSubmitted: (_) => _sendAtCommand(),
            textInputAction: TextInputAction.send,
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.accentPrimary,
            foregroundColor: AppTheme.textPrimary,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _sendAtCommand,
          child: const Text('Отправить'),
        ),
      ],
    );
  }
}
