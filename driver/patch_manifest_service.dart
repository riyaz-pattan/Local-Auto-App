import 'dart:io';

void main() {
  String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  
  String serviceTag = '''
        <service
            android:name="com.pravera.flutter_foreground_task.services.ForegroundService"
            android:foregroundServiceType="location"
            android:exported="false" />
    </application>''';

  if (!manifest.contains("com.pravera.flutter_foreground_task.services.ForegroundService")) {
    manifest = manifest.replaceFirst('</application>', serviceTag);
    File('android/app/src/main/AndroidManifest.xml').writeAsStringSync(manifest);
    print('Service added to manifest');
  } else {
    print('Service already exists');
  }
}
