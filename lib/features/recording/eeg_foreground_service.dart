import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// keeps app alive when minimized or screen locked during recording
bool foregroundTaskInited = false;

// required for isolate entry; do not rename
@pragma('vm:entry-point')
void startEegForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(EegForegroundTaskHandler());
}

// minimal handler; only onNotificationPressed implemented (launch app)
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

  // tap notification → launch app
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

// init notification channel and task options; one-time
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

// starts foreground service; shows persistent notification
Future<void> startEegForegroundService() async {
  await ensureEegForegroundTaskInited();
  await FlutterForegroundTask.startService(
    notificationTitle: 'Запись ЭЭГ',
    notificationText: 'Идёт запись. Нажмите, чтобы открыть приложение.',
    serviceTypes: [ForegroundServiceTypes.connectedDevice],
    callback: startEegForegroundCallback,
  );
}

// stops foreground service
Future<void> stopEegForegroundService() async {
  await FlutterForegroundTask.stopService();
}

// stops leftover service from previous run (e.g. crash); call at startup
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
