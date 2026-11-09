import 'dart:io';

void main() {
  String code = File('lib/screens/onboarding_screen.dart').readAsStringSync();

  // 1. Update constructor
  String oldClassDef = '''class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}''';
  String newClassDef = '''class OnboardingScreen extends StatefulWidget {
  final bool isResubmission;
  final String? rejectionReason;
  
  const OnboardingScreen({super.key, this.isResubmission = false, this.rejectionReason});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}''';
  code = code.replaceFirst(oldClassDef, newClassDef);

  // 2. Add fetching in initState
  String oldInit = '''  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null) {
      _phoneController.text = user!.phoneNumber!.replaceFirst('+91', '');
    }
  }''';
  String newInit = '''  bool _loadingData = false;
  String? _existingProfileUrl;
  String? _existingAadhaarUrl;
  String? _existingLicenseUrl;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null) {
      _phoneController.text = user!.phoneNumber!.replaceFirst('+91', '');
    }
    if (widget.isResubmission) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _loadingData = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('drivers').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          _nameController.text = data['name'] ?? '';
          _phoneController.text = (data['phone'] ?? '').replaceFirst('+91', '');
          _vehicleNumberController.text = data['vehicleNumber'] ?? '';
          
          _existingProfileUrl = data['profilePhotoUrl'];
          _existingAadhaarUrl = data['aadhaarUrl'];
          _existingLicenseUrl = data['licenseUrl'];
        }
      }
    } catch (e) {
      print('Error loading data: \$e');
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }''';
  code = code.replaceFirst(oldInit, newInit);

  // 3. Display rejection reason at top of _buildStep1
  String oldStep1Start = '''            Text(
              'Personal Details',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),''';
  String newStep1Start = '''            if (widget.isResubmission && widget.rejectionReason != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Reason for Rejection', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.rejectionReason!, style: GoogleFonts.inter(color: Colors.red.shade900)),
                  ],
                ),
              ),
            Text(
              'Personal Details',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),''';
  code = code.replaceFirst(oldStep1Start, newStep1Start);

  // 4. In _buildUploadCard, update logic for existing images
  String oldUploadCard = '''        child: Row(
          children: [
            if (file != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
              )
            else
              Container(
                width: 56,
                height: 56,''';
  String newUploadCard = '''        child: Row(
          children: [
            if (file != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
              )
            else if (title.contains('Profile') && _existingProfileUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(_existingProfileUrl!, width: 56, height: 56, fit: BoxFit.cover),
              )
            else if (title.contains('Aadhaar') && _existingAadhaarUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(_existingAadhaarUrl!, width: 56, height: 56, fit: BoxFit.cover),
              )
            else if (title.contains('License') && _existingLicenseUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(_existingLicenseUrl!, width: 56, height: 56, fit: BoxFit.cover),
              )
            else
              Container(
                width: 56,
                height: 56,''';
  code = code.replaceFirst(oldUploadCard, newUploadCard);

  // 5. Update _submit to use existing urls if files aren't picked, and set status to pending
  String submitOld = '''    if (_profilePhoto == null || _aadhaarPhoto == null || _licensePhoto == null) {
      _showSnackBar('Please upload all required documents');
      return;
    }''';
  String submitNew = '''    if ((_profilePhoto == null && _existingProfileUrl == null) || 
        (_aadhaarPhoto == null && _existingAadhaarUrl == null) || 
        (_licensePhoto == null && _existingLicenseUrl == null)) {
      _showSnackBar('Please upload all required documents');
      return;
    }''';
  code = code.replaceFirst(submitOld, submitNew);
  
  String uploadOld = '''      // Upload images
      final profileUrl = await _uploadFile(
        _profilePhoto!,
        'drivers/\$uid/profile.jpg',
      );
      final aadhaarUrl = await _uploadFile(
        _aadhaarPhoto!,
        'drivers/\$uid/aadhaar.jpg',
      );
      final licenseUrl = await _uploadFile(
        _licensePhoto!,
        'drivers/\$uid/license.jpg',
      );''';
  String uploadNew = '''      // Upload images or use existing
      final profileUrl = _profilePhoto != null ? await _uploadFile(_profilePhoto!, 'drivers/\$uid/profile.jpg') : _existingProfileUrl!;
      final aadhaarUrl = _aadhaarPhoto != null ? await _uploadFile(_aadhaarPhoto!, 'drivers/\$uid/aadhaar.jpg') : _existingAadhaarUrl!;
      final licenseUrl = _licensePhoto != null ? await _uploadFile(_licensePhoto!, 'drivers/\$uid/license.jpg') : _existingLicenseUrl!;''';
  code = code.replaceFirst(uploadOld, uploadNew);

  String setOld = '''        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });''';
  String setNew = '''        'status': 'pending',
        'rejectionReason': FieldValue.delete(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));''';
  code = code.replaceFirst(setOld, setNew);

  // Fix loading state on whole body
  String buildOld = '''    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Driver Registration',''';
  String buildNew = '''    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Driver Registration',''';
  code = code.replaceFirst(buildOld, buildNew);
  
  String bodyOld = '''      body: SafeArea(
        child: Column(''';
  String bodyNew = '''      body: SafeArea(
        child: _loadingData ? const Center(child: CircularProgressIndicator()) : Column(''';
  code = code.replaceFirst(bodyOld, bodyNew);
  
  File('lib/screens/onboarding_screen.dart').writeAsStringSync(code);
  print('Onboarding patched');
}
