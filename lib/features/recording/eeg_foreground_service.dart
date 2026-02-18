import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Foreground service for EEG recording.
/// Keeps the app alive when minimized or screen is locked.
bool foregroundTaskInited = false;

@pragma('vm:entry-point')
void startEegForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(EegForegroundTaskHandler());
}

class EegForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

Future<void> ensureEegForegroundTaskInited() async {
  if (foregroundTaskInited) return;
  final notifPerm =
      await FlutterForegroundTask.checkNotificationPermission();
  if (notifPerm != NotificationPermission.granted) {
    await FlutterForegroundTask.requestNotificationPermission();
  }
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'eeg_recording',
      channelName: 'Запись ЭЭГ',
      channelDescription: 'Уведомление во время записи ЭЭГ',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(60000),
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
  foregroundTaskInited = true;
}

Future<void> startEegForegroundService() async {
  await ensureEegForegroundTaskInited();
  await FlutterForegroundTask.startService(
    notificationTitle: 'Запись ЭЭГ',
    notificationText: 'Идёт запись. Нажмите, чтобы открыть приложение.',
    serviceTypes: [ForegroundServiceTypes.connectedDevice],
    callback: startEegForegroundCallback,
  );
}

Future<void> stopEegForegroundService() async {
  await FlutterForegroundTask.stopService();
}

/// Stops foreground service if still running after app restart (e.g. after crash).
Future<void> stopOrphanedForegroundServiceIfNeeded() async {
  try {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await ensureEegForegroundTaskInited();
      await FlutterForegroundTask.stopService();
    }
  } on Object {
    // Service may not be initialized yet
  }
}
