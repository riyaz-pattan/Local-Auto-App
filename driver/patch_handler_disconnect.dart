import 'dart:io';

void main() {
  String code = File('lib/services/foreground_service_handler.dart').readAsStringSync();
  
  String oldSet = "FirebaseDatabase.instance.ref('liveLocations/\\\$_uid').set({";
  String newSet = "FirebaseDatabase.instance.ref('liveLocations/\\\$_uid').onDisconnect().remove();\n        FirebaseDatabase.instance.ref('liveLocations/\\\$_uid').set({";
  
  if (code.contains("onDisconnect().remove();") == false) {
    code = code.replaceFirst(
      "FirebaseDatabase.instance.ref('liveLocations/\$_uid').set({",
      "FirebaseDatabase.instance.ref('liveLocations/\$_uid').onDisconnect().remove();\n        FirebaseDatabase.instance.ref('liveLocations/\$_uid').set({"
    );
    File('lib/services/foreground_service_handler.dart').writeAsStringSync(code);
    print('Added onDisconnect to handler');
  } else {
    print('Already has onDisconnect');
  }
}
