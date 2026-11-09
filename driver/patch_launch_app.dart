import 'dart:io';

void main() {
  String handlerCode = File('lib/services/foreground_service_handler.dart').readAsStringSync();
  
  handlerCode = handlerCode.replaceAll(
    "  @override\n  void onNotificationPressed() {\n    FlutterForegroundTask.launchApp();\n  }",
    "  @override\n  void onNotificationPressed() {\n    // Use notificationInitialRoute instead\n  }"
  );

  File('lib/services/foreground_service_handler.dart').writeAsStringSync(handlerCode);
  
  String dashboardCode = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldStart = '''      notificationButtons: [
        const NotificationButton(id: 'go_offline', text: 'GO OFFLINE'),
      ],
      callback: startCallback,''';
      
  String newStart = '''      notificationButtons: [
        const NotificationButton(id: 'go_offline', text: 'GO OFFLINE'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,''';

  dashboardCode = dashboardCode.replaceFirst(oldStart, newStart);
  File('lib/screens/dashboard_screen.dart').writeAsStringSync(dashboardCode);
  
  print('launchApp removed and initialRoute added');
}
