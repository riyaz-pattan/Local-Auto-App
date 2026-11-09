import 'dart:io';

void main() {
  String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  
  manifest = manifest.replaceAll(
    '<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />',
    '<!-- Removed ACCESS_BACKGROUND_LOCATION to comply with Google Play Policy without needing full background location declaration -->'
  );

  File('android/app/src/main/AndroidManifest.xml').writeAsStringSync(manifest);
  print('Removed ACCESS_BACKGROUND_LOCATION');
}
