import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldStart = '''    await FlutterForegroundTask.startService(
      notificationTitle: 'Local Auto: Online',
      notificationText: 'You are visible to nearby riders.',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'go_offline', text: 'GO OFFLINE'),
      ],
      callback: startCallback,
    );''';
    
  String newStart = '''    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'Local Auto: Online',
      notificationText: 'You are visible to nearby riders.',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'go_offline', text: 'GO OFFLINE'),
      ],
      callback: startCallback,
    );
    if (result is ServiceRequestFailure) {
      print('Service Start Failure: \${result.error}');
    }''';

  code = code.replaceFirst(oldStart, newStart);
  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Patched startService result');
}
