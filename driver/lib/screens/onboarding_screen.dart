import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../utils/custom_toast.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}


class OnboardingScreen extends StatefulWidget {
  final bool isResubmission;
  final String? rejectionReason;
  
  const OnboardingScreen({super.key, this.isResubmission = false, this.rejectionReason});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _submitting = false;

  File? _profilePhoto;
  File? _aadhaarPhoto;
  File? _licensePhoto;

  final _picker = ImagePicker();

  bool _loadingData = false;
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
      print('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _vehicleNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
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
  }

  Future<String> _uploadFile(File file, String path) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if ((_profilePhoto == null && _existingProfileUrl == null) || 
        (_aadhaarPhoto == null && _existingAadhaarUrl == null) || 
        (_licensePhoto == null && _existingLicenseUrl == null)) {
      _showSnackBar('Please upload all required documents');
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Upload images or use existing
      final profileUrl = _profilePhoto != null ? await _uploadFile(_profilePhoto!, 'drivers/$uid/profile.jpg') : _existingProfileUrl!;
      final aadhaarUrl = _aadhaarPhoto != null ? await _uploadFile(_aadhaarPhoto!, 'drivers/$uid/aadhaar.jpg') : _existingAadhaarUrl!;
      final licenseUrl = _licensePhoto != null ? await _uploadFile(_licensePhoto!, 'drivers/$uid/license.jpg') : _existingLicenseUrl!;

      // Save to Firestore
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'phone': '+91${_phoneController.text.trim()}',
        'vehicleNumber': _vehicleNumberController.text.trim().toUpperCase(),
        'profilePhotoUrl': profileUrl,
        'aadhaarUrl': aadhaarUrl,
        'licenseUrl': licenseUrl,
        'status': 'pending',
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
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    CustomToast.show(context, message);
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Driver Registration',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loadingData 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              children: [
                _buildStepDot(0, theme),
                Expanded(
                  child: Container(
                    height: 2,
                    color:
                        _currentStep >= 1
                            ? theme.primary
                            : theme.outlineVariant,
                  ),
                ),
                _buildStepDot(1, theme),
              ],
            ),
          ),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [_buildStep1(), _buildStep2()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, ColorScheme theme) {
    final isActive = _currentStep >= step;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? theme.primary : theme.surfaceContainerHighest,
      ),
      child: Center(
        child: Text(
          '${step + 1}',
          style: GoogleFonts.inter(
            color: isActive ? theme.onPrimary : theme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isResubmission && widget.rejectionReason != null)
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
            ),
            const SizedBox(height: 8),
            Text(
              'Please fill in your details to register as a driver.',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            TextFormField(
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
            ),
            const SizedBox(height: 16),
            TextFormField(
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
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _nextStep,
                child: const Text('Next - Upload Documents'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Documents',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload clear photos of the following documents.',
            style: GoogleFonts.inter(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          _buildUploadCard(
            title: 'Profile Photo',
            icon: Icons.account_circle_outlined,
            file: _profilePhoto,
            onTap: () => _pickImage('profile'),
          ),
          const SizedBox(height: 16),
          _buildUploadCard(
            title: 'Aadhaar Card',
            icon: Icons.badge_outlined,
            file: _aadhaarPhoto,
            onTap: () => _pickImage('aadhaar'),
          ),
          const SizedBox(height: 16),
          _buildUploadCard(
            title: 'Driving License',
            icon: Icons.card_membership_outlined,
            file: _licensePhoto,
            onTap: () => _pickImage('license'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child:
                  _submitting
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text(widget.isResubmission ? 'Resubmit Profile' : 'Submit for Review'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed:
                  _submitting
                      ? null
                      : () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
              child: const Text('Back'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({
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
        child: Row(
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
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 28, color: Colors.grey[600]),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasImage ? 'Tap to change' : 'Tap to upload',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasImage ? Icons.check_circle : Icons.upload_outlined,
              color: hasImage ? Colors.green : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
