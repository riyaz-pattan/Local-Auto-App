import 'dart:io';

void main() {
  String code = File('lib/screens/onboarding_screen.dart').readAsStringSync();
  
  // 1. Insert UpperCaseTextFormatter at the top
  String imports = "import '../utils/custom_toast.dart';";
  String formatter = '''import 'package:flutter/services.dart';
import '../utils/custom_toast.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}''';
  if (code.contains(imports)) {
    code = code.replaceFirst(imports, formatter);
  }

  // 2. Patch phone field
  String oldPhoneField = '''            TextFormField(
              controller: _phoneController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+91 ',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),''';
  String newPhoneField = '''            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+91 ',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
              validator: (v) {
                if (v == null || v.trim().length != 10 || int.tryParse(v.trim()) == null) {
                  return 'Mobile number must be exactly 10 digits';
                }
                return null;
              },
            ),''';
  if (code.contains(oldPhoneField)) {
    code = code.replaceFirst(oldPhoneField, newPhoneField);
  }

  // 3. Patch name field
  String oldNameField = '''            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
            ),''';
  String newNameField = '''            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
            ),''';
  if (code.contains(oldNameField)) {
    code = code.replaceFirst(oldNameField, newNameField);
  }

  // 4. Patch vehicle field
  String oldVehicleField = '''            TextFormField(
              controller: _vehicleNumberController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                hintText: 'e.g. KA 01 AB 1234',
                prefixIcon: const Icon(Icons.directions_car_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Vehicle number is required'
                          : null,
            ),''';
  String newVehicleField = '''            TextFormField(
              controller: _vehicleNumberController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: InputDecoration(
                labelText: 'Vehicle Number',
                hintText: 'e.g. KA 01 AB 1234',
                prefixIcon: const Icon(Icons.directions_car_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Vehicle number is required'
                          : null,
            ),''';
  if (code.contains(oldVehicleField)) {
    code = code.replaceFirst(oldVehicleField, newVehicleField);
  }

  File('lib/screens/onboarding_screen.dart').writeAsStringSync(code);
}
