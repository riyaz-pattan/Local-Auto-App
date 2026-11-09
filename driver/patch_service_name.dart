import 'dart:io';

void main() {
  String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  
  manifest = manifest.replaceFirst(
    'android:name="com.pravera.flutter_foreground_task.services.ForegroundService"',
    'android:name="com.pravera.flutter_foreground_task.service.ForegroundService"'
  );

  File('android/app/src/main/AndroidManifest.xml').writeAsStringSync(manifest);
  print('Service name fixed in manifest');
}
