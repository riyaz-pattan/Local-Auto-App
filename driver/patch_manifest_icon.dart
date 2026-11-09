import 'dart:io';

void main() {
  String manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  
  if (!manifest.contains('android:name="ic_notification"')) {
    String metaData = '''
        <meta-data
            android:name="ic_notification"
            android:resource="@drawable/ic_notification" />
''';
    
    // insert right before the closing </application> tag
    manifest = manifest.replaceFirst('</application>', '\$metaData    </application>');
    File('android/app/src/main/AndroidManifest.xml').writeAsStringSync(manifest);
    print('Added ic_notification to manifest');
  } else {
    print('ic_notification already in manifest');
  }
}
