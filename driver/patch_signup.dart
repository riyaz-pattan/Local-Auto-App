import 'dart:io';

void main() {
  String code = File('lib/screens/email_signup_screen.dart').readAsStringSync();
  
  String oldBlock = '''      if (mounted) {
        CustomToast.show(context, 'Account created! Verification email sent.');
        // Sign out immediately so they have to sign in
        await FirebaseAuth.instance.signOut();
        // Go back to Sign In Screen as requested
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmailSignInScreen()));
      }''';
      
  String newBlock = '''      if (mounted) {
        CustomToast.show(context, 'Account created! Verification email sent.');
      }
      
      // Sign out immediately so they have to sign in
      await FirebaseAuth.instance.signOut();
      
      if (mounted) {
        // Go back to Sign In Screen as requested
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmailSignInScreen()));
      }''';

  code = code.replaceAll(oldBlock, newBlock);
  File('lib/screens/email_signup_screen.dart').writeAsStringSync(code);
}
