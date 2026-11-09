import 'dart:io';

void main() {
  String code = File('lib/screens/login_options_screen.dart').readAsStringSync();
  
  String oldSignIn = '''    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();''';
      
  String newSignIn = '''    try {
      // Force account picker by clearing any previous cached sign-in
      await GoogleSignIn().signOut();
      
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();''';

  code = code.replaceFirst(oldSignIn, newSignIn);
  File('lib/screens/login_options_screen.dart').writeAsStringSync(code);
  
  print('Patched Google Sign In to force account picker');
}
