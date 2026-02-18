import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// minimal task handler for foreground service during EEG recording
// keeps the app alive when minimized or screen is locked

bool foregroundTaskInited = false;

@pragma('vm:entry-point')
void startEegForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(EegForegroundTaskHandler());
}

// eeg foreground task handler
class EegForegroundTaskHandler extends TaskHandler {
  // on start
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  // on repeat event
  @override
  void onRepeatEvent(DateTime timestamp) {}

  // on destroy
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  // on receive data
  @override
  void onReceiveData(Object data) {}

  // on notification button pressed
  @override
  void onNotificationButtonPressed(String id) {}

  // on notification pressed
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
  // on notification dismissed
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

/// Stops foreground service if it's still running after app restart (e.g. after crash).
/// Call at app startup when recording is not active.
Future<void> stopOrphanedForegroundServiceIfNeeded() async {
  try {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await ensureEegForegroundTaskInited();
      await FlutterForegroundTask.stopService();
    }
  } catch (_) {
    // ignore: service may not be initialized yet
  }
}
