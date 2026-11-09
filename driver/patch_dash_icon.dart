import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldIcon = "notificationIcon: null,";
  String newIcon = "notificationIcon: const NotificationIcon(metaDataName: 'ic_notification'),";
  
  if (code.contains(oldIcon)) {
    code = code.replaceFirst(oldIcon, newIcon);
    File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
    print('Patched notificationIcon');
  } else {
    print('Could not find notificationIcon: null,');
  }
}
