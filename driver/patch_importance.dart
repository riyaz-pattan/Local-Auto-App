import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  code = code.replaceAll(
    "channelImportance: NotificationChannelImportance.DEFAULT,", 
    "channelImportance: NotificationChannelImportance.HIGH,"
  );
  
  code = code.replaceAll(
    "priority: NotificationPriority.DEFAULT,", 
    "priority: NotificationPriority.HIGH,"
  );
  
  code = code.replaceAll(
    "channelId: 'driver_online_service_v3',", 
    "channelId: 'driver_online_service_v4',"
  );

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Importance patched');
}
