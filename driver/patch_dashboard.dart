import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  if (!code.contains("import 'package:flutter_foreground_task/flutter_foreground_task.dart';")) {
    code = code.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:flutter_foreground_task/flutter_foreground_task.dart';\nimport '../services/foreground_service_handler.dart';"
    );
  }

  // Inside initState
  String oldInit = '''  @override
  void initState() {
    super.initState();''';

  String newInit = '''  @override
  void initState() {
    super.initState();
    _initForegroundTask();''';

  if (code.contains(oldInit) && !code.contains("_initForegroundTask()")) {
    code = code.replaceFirst(oldInit, newInit);
  }

  // Add the _initForegroundTask method
  String initMethod = '''
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driver_foreground_service',
        channelName: 'Driver Online Service',
        channelDescription: 'Keeps the driver online and tracks location in the background.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(id: 'go_offline', text: 'GO OFFLINE'),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }
''';

  if (!code.contains("_initForegroundTask() {")) {
    code = code.replaceFirst(
      "  void _initPulseAnimation() {",
      initMethod + "\n  void _initPulseAnimation() {"
    );
  }

  // In _goOnline
  String goOnlineSearch = "    // await _rtdb.ref('liveLocations/\$_uid').onDisconnect().remove(); // Removed to keep driver online when app is closed";
  if (!code.contains("FlutterForegroundTask.startService(")) {
    code = code.replaceFirst(
      goOnlineSearch,
      goOnlineSearch + "\n    await FlutterForegroundTask.saveData(key: 'uid', value: _uid);\n    await FlutterForegroundTask.startService(\n      notificationTitle: 'Local Auto: Online',\n      notificationText: 'You are visible to nearby riders.',\n      callback: startCallback,\n    );"
    );
  }

  // In _goOffline
  String goOfflineSearch = "    final ref = _rtdb.ref('liveLocations/\$_uid');";
  if (!code.contains("FlutterForegroundTask.stopService()")) {
    code = code.replaceFirst(
      goOfflineSearch,
      "    await FlutterForegroundTask.stopService();\n" + goOfflineSearch
    );
  }
  
  // Need to handle permissions
  String permsCheck = '''
  Future<void> _requestForegroundPermissions() async {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    NotificationPermission notificationPermissionStatus = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }
''';
  if (!code.contains("_requestForegroundPermissions")) {
     code = code.replaceFirst("  Future<void> _fetchDriverName()", permsCheck + "\n  Future<void> _fetchDriverName()");
     
     // add call to _goOnline
     code = code.replaceFirst(
       "Future<void> _goOnline() async {",
       "Future<void> _goOnline() async {\n    await _requestForegroundPermissions();"
     );
  }

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Dashboard patched');
}
