import 'dart:io';

void main() {
  String code = File('lib/screens/onboarding_screen.dart').readAsStringSync();
  
  String oldPickImage = '''  Future<void> _pickImage(String type) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 20,
    );
    if (picked == null) return;
    setState(() {
      switch (type) {
        case 'profile':
          _profilePhoto = File(picked.path);
          break;
        case 'aadhaar':
          _aadhaarPhoto = File(picked.path);
          break;
        case 'license':
          _licensePhoto = File(picked.path);
          break;
      }
    });
  }''';
  
  String newPickImage = '''  Future<void> _pickImage(String type) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    'Select Image Source',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 28),
                  title: const Text('Camera', style: TextStyle(fontSize: 16)),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green, size: 28),
                  title: const Text('Gallery', style: TextStyle(fontSize: 16)),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 20,
    );
    if (picked == null) return;
    setState(() {
      switch (type) {
        case 'profile':
          _profilePhoto = File(picked.path);
          break;
        case 'aadhaar':
          _aadhaarPhoto = File(picked.path);
          break;
        case 'license':
          _licensePhoto = File(picked.path);
          break;
      }
    });
  }''';
  
  code = code.replaceFirst(oldPickImage, newPickImage);
  File('lib/screens/onboarding_screen.dart').writeAsStringSync(code);
  print('Patched _pickImage');
}
