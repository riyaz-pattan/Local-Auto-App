import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldBlock = '''    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
        'isOnline': false,
      });
    } catch (e) {
      print('Firestore offline error (ignored): \$e');
    }''';

  code = code.replaceFirst(oldBlock, "");
  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Removed Firestore offline write');
}
