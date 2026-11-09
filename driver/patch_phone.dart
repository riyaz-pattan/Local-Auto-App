import 'dart:io';

void main() {
  String code = File('lib/screens/onboarding_screen.dart').readAsStringSync();
  
  String oldPhoneField = '''            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(''';
              
  String newPhoneField = '''            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              decoration: InputDecoration(''';
              
  if (code.contains(oldPhoneField)) {
    code = code.replaceFirst(oldPhoneField, newPhoneField);
    File('lib/screens/onboarding_screen.dart').writeAsStringSync(code);
    print('Phone patched');
  } else {
    print('Failed to patch phone field');
  }
}
