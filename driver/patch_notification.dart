import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  // Replace the bad notificationIcon line
  String badIconRegex = r"notificationIcon: const NotificationIcon\(\n        metaDataName: 'io.flutter.embedding.android.NormalTheme', // fallback\n      \),";
  
  code = code.replaceFirst(RegExp(badIconRegex), "notificationIcon: null,");

  // Just to be sure, check if the string was replaced
  if (!code.contains("notificationIcon: null,")) {
    // maybe formatted differently
    code = code.replaceFirst("metaDataName: 'io.flutter.embedding.android.NormalTheme'", "metaDataName: 'ic_launcher'");
  }

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Patched notificationIcon');
}
