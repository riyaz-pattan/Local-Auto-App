import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  // Replace _initForegroundTask
  String oldInitRegex = r"void _initForegroundTask\(\) \{[\s\S]*?allowWifiLock: true,\n      \),\n    \);\n  \}";
  
  String newInit = '''
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driver_foreground_service',
        channelName: 'Driver Online Service',
        channelDescription: 'Keeps the driver online and tracks location in the background.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }
''';

  code = code.replaceAll(RegExp(oldInitRegex), newInit.trim());
  
  // Replace startService
  String oldStartRegex = r"await FlutterForegroundTask\.startService\([\s\S]*?callback: startCallback,\n    \);";
  String newStart = '''await FlutterForegroundTask.startService(
      notificationTitle: 'Local Auto: Online',
      notificationText: 'You are visible to nearby riders.',
      notificationIcon: const NotificationIcon(
        metaDataName: 'io.flutter.embedding.android.NormalTheme', // fallback
      ),
      notificationButtons: [
        const NotificationButton(id: 'go_offline', text: 'GO OFFLINE'),
      ],
      callback: startCallback,
    );''';
    
  code = code.replaceAll(RegExp(oldStartRegex), newStart);

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Fixed dashboard API issues');
}
