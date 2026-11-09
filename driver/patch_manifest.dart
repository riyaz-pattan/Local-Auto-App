import 'dart:io';

void main() {
  String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  
  String newPermissions = '''
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
''';

  manifest = manifest.replaceFirst(
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    newPermissions.trim()
  );

  File('android/app/src/main/AndroidManifest.xml').writeAsStringSync(manifest);
  print('Manifest updated');
}
