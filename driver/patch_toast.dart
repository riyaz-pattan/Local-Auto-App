import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  
  String oldSnackbar = '''              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You have been logged out because you logged in on another device.'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }''';
              
  String newToast = '''              Fluttertoast.showToast(
                msg: 'Logged out: You logged in on another device.',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 5,
                backgroundColor: Colors.redAccent,
                textColor: Colors.white,
                fontSize: 16.0,
              );''';

  code = code.replaceFirst(oldSnackbar, newToast);

  if (!code.contains("import 'package:fluttertoast/fluttertoast.dart';")) {
    code = code.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:fluttertoast/fluttertoast.dart';"
    );
  }

  File('lib/main.dart').writeAsStringSync(code);
  print('Patched toast');
}
