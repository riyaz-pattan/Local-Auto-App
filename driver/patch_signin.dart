import 'dart:io';

void main() {
  String code = File('lib/screens/email_signin_screen.dart').readAsStringSync();
  
  // 1. Add state variable
  String oldStateVars = '''  final _passwordController = TextEditingController();
  bool _loading = false;''';
  String newStateVars = '''  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;''';
  if (code.contains(oldStateVars)) {
    code = code.replaceAll(oldStateVars, newStateVars);
  } else {
    print('Failed to patch state vars');
  }

  // 2. Update Password field
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

  File('lib/screens/email_signin_screen.dart').writeAsStringSync(code);
}
