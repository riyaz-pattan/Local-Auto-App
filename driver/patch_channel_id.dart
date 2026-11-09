import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  code = code.replaceAll(
    "channelId: 'driver_foreground_service',", 
    "channelId: 'driver_online_service_v3',"
  );

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Channel ID patched');
}
