import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  
  String oldToast = '''              Fluttertoast.showToast(
                msg: 'Logged out: You logged in on another device.',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 5,
                backgroundColor: Colors.redAccent,
                textColor: Colors.white,
                fontSize: 16.0,
              );''';
              
  String newToast = '''              if (mounted) {
                CustomToast.show(context, 'Logged out: You logged in on another device.');
              }''';

  code = code.replaceFirst(oldToast, newToast);

  if (!code.contains("import 'utils/custom_toast.dart';")) {
    code = code.replaceFirst(
      "import 'package:fluttertoast/fluttertoast.dart';",
      "import 'utils/custom_toast.dart';"
    );
  }

  File('lib/main.dart').writeAsStringSync(code);
  
  // Remove fluttertoast from pubspec
  String pubspec = File('pubspec.yaml').readAsStringSync();
  pubspec = pubspec.replaceAll(RegExp(r'^\s*fluttertoast:.*\$', multiLine: true), '');
  File('pubspec.yaml').writeAsStringSync(pubspec);
  
  print('Patched custom toast');
}
