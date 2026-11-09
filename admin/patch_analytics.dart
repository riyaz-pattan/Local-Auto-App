import 'dart:io';

void main() {
  String code = File('lib/screens/analytics_tab.dart').readAsStringSync();
  
  String oldName = "String name = 'Driver #\${driverId.substring(0, driverId.length > 6 ? 6 : driverId.length).toUpperCase()}';";
  String newName = "String name = 'Deleted/Unknown Driver';";
  
  if (code.contains(oldName)) {
    code = code.replaceFirst(oldName, newName);
    File('lib/screens/analytics_tab.dart').writeAsStringSync(code);
    print('Analytics patched');
  } else {
    print('Analytics patch failed');
  }
}
