import 'dart:io';

void main() {
  String code = File('lib/screens/email_signup_screen.dart').readAsStringSync();
  
  // 1. Add state variables for obscure text
  String oldStateVars = '''  final _confirmPasswordController = TextEditingController();
  bool _loading = false;''';
  String newStateVars = '''  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;''';
  if (code.contains(oldStateVars)) {
    code = code.replaceAll(oldStateVars, newStateVars);
  } else {
    print('Failed to patch state vars');
  }

  // 2. Remove email verification and update toast
  String oldSignupLogic = '''      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      // Send free verification email
      await cred.user?.sendEmailVerification();
      
      if (mounted) {
        CustomToast.show(context, 'Account created! Verification email sent.');
      }''';
  String newSignupLogic = '''      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      
      if (mounted) {
        CustomToast.show(context, 'Account created successfully! Now log in again.', isError: false);
      }''';
  if (code.contains(oldSignupLogic)) {
    code = code.replaceAll(oldSignupLogic, newSignupLogic);
  } else {
    print('Failed to patch signup logic');
  }

  // 3. Update Password field
  String oldPassField = '''                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),''';
  String newPassField = '''                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),''';
  if (code.contains(oldPassField)) {
    code = code.replaceAll(oldPassField, newPassField);
  } else {
    print('Failed to patch pass field');
  }

  // 4. Update Confirm Password field
  String oldConfirmField = '''                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),''';
  String newConfirmField = '''                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),''';
  if (code.contains(oldConfirmField)) {
    code = code.replaceAll(oldConfirmField, newConfirmField);
  } else {
    print('Failed to patch confirm field');
  }

  File('lib/screens/email_signup_screen.dart').writeAsStringSync(code);
}
