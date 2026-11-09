import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  code = code.replaceFirst(
    "if (snapshot.metadata.isFromCache) {",
    "if (snapshot.data!.metadata.isFromCache) {"
  );
  File('lib/main.dart').writeAsStringSync(code);
  print('Fixed snapshot.data!.metadata');
}
