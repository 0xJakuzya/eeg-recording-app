import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// minimal task handler for foreground service during EEG recording
// keeps the app alive when minimized or screen is locked
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
