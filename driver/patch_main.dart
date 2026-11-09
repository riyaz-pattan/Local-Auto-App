import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  
  if (!code.contains("import 'package:flutter_foreground_task/flutter_foreground_task.dart';")) {
    code = code.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:flutter_foreground_task/flutter_foreground_task.dart';"
    );
  }

  if (code.contains("WidgetsFlutterBinding.ensureInitialized();")) {
    if (!code.contains("FlutterForegroundTask.initCommunicationPort();")) {
      code = code.replaceFirst(
        "WidgetsFlutterBinding.ensureInitialized();",
        "WidgetsFlutterBinding.ensureInitialized();\n  FlutterForegroundTask.initCommunicationPort();"
      );
    }
  }

  File('lib/main.dart').writeAsStringSync(code);
  print('main patched');
}
