import 'dart:io';

void main() {
  String code = File('lib/screens/onboarding_screen.dart').readAsStringSync();

  // 1. Update _buildUploadCard
  String oldUploadMethodStart = '''  Widget _buildUploadCard({
    required String title,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                file != null
                    ? Colors.green
                    : Theme.of(context).colorScheme.outlineVariant,
            width: file != null ? 2 : 1,
          ),
        ),
        child: Row(''';
        
  String newUploadMethodStart = '''  Widget _buildUploadCard({
    required String title,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    bool hasImage = file != null || 
        (title.contains('Profile') && _existingProfileUrl != null) ||
        (title.contains('Aadhaar') && _existingAadhaarUrl != null) ||
        (title.contains('License') && _existingLicenseUrl != null);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? Colors.green : Theme.of(context).colorScheme.outlineVariant,
            width: hasImage ? 2 : 1,
          ),
        ),
        child: Row(''';
  code = code.replaceFirst(oldUploadMethodStart, newUploadMethodStart);

  // Update text
  String oldText = '''                  Text(
                    file != null ? 'Tap to change' : 'Tap to upload',''';
  String newText = '''                  Text(
                    hasImage ? 'Tap to change' : 'Tap to upload',''';
  code = code.replaceFirst(oldText, newText);

  // Update icon
  String oldIcon = '''            Icon(
              file != null ? Icons.check_circle : Icons.upload_outlined,
              color: file != null ? Colors.green : Colors.grey[400],
            ),''';
  String newIcon = '''            Icon(
              hasImage ? Icons.check_circle : Icons.upload_outlined,
              color: hasImage ? Colors.green : Colors.grey[400],
            ),''';
  code = code.replaceFirst(oldIcon, newIcon);

  // 2. Update Submit Button text
  String oldButtonText = "                      : const Text('Submit for Review'),";
  String newButtonText = "                      : Text(widget.isResubmission ? 'Resubmit Profile' : 'Submit for Review'),";
  code = code.replaceFirst(oldButtonText, newButtonText);

  // 3. Update Submit method to pop & toast
  String oldSubmitEnd = '''        'status': 'pending',
        'rejectionReason': FieldValue.delete(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ProfileGate in main.dart handles navigation automatically
    } catch (e) {''';
    
  String newSubmitEnd = '''        'status': 'pending',
        'rejectionReason': FieldValue.delete(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        if (widget.isResubmission) {
          CustomToast.show(context, 'Profile resubmitted successfully', isError: false);
          Navigator.pop(context);
        } else {
          CustomToast.show(context, 'Profile submitted successfully', isError: false);
          // ProfileGate will take over automatically
        }
      }
    } catch (e) {''';
  code = code.replaceFirst(oldSubmitEnd, newSubmitEnd);

  File('lib/screens/onboarding_screen.dart').writeAsStringSync(code);
  print('Onboarding card and submit patched');
}
