import 'dart:io';

void main() {
  String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  
  if (manifest.contains('android:foregroundServiceType="location"')) {
    if (!manifest.contains('android:stopWithTask')) {
      manifest = manifest.replaceFirst(
        'android:foregroundServiceType="location"',
        'android:foregroundServiceType="location"\n            android:stopWithTask="false"'
      );
      File('android/app/src/main/AndroidManifest.xml').writeAsStringSync(manifest);
      print('Added stopWithTask="false"');
    }
  }
}
