import 'dart:io';

void main() {
  String code = File('lib/screens/user_management_tab.dart').readAsStringSync();

  // 1. Add rejection reasons and state to _DriverDetailSheetState
  String stateStart = 'class _DriverDetailSheetState extends State<DriverDetailSheet> {';
  String stateVars = '''class _DriverDetailSheetState extends State<DriverDetailSheet> {
  bool _isLoading = false;
  final List<String> _rejectionReasons = [
    'Profile photo is blurry or unclear',
    'Aadhaar card details are not visible',
    'Driving license is expired or invalid',
    'Vehicle number does not match documents',
    'Fraudulent or duplicate profile',
    'Other (Specify below)'
  ];''';
  if (code.contains(stateStart)) {
    code = code.replaceFirst(stateStart, stateVars);
  }

  // 2. Add _showRejectionDialog method
  String updateStatusMethod = '  Future<void> _updateStatus(String status) async {';
  String showRejectionMethod = '''
  void _showRejectionDialog() {
    String selectedReason = _rejectionReasons.first;
    final manualReasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reject Driver', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Select reason for rejection:'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _rejectionReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        setModalState(() => selectedReason = val!);
                      },
                    ),
                    if (selectedReason.startsWith('Other')) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: manualReasonController,
                        decoration: InputDecoration(
                          labelText: 'Enter reason',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 3,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          final finalReason = selectedReason.startsWith('Other') 
                              ? manualReasonController.text.trim() 
                              : selectedReason;
                          if (finalReason.isEmpty) return;
                          
                          Navigator.pop(ctx);
                          _updateStatus('rejected', reason: finalReason);
                        },
                        child: const Text('Confirm Rejection'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(String status, {String? reason}) async {
    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('updateDriverStatus');
      await callable.call({
        'driverId': widget.driverId,
        'status': status,
        if (reason != null) 'rejectionReason': reason,
      });
      if (mounted) Navigator.pop(context); // Close the detail sheet
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }''';

  // Replace _updateStatus completely
  int startIdx = code.indexOf(updateStatusMethod);
  int endIdx = code.indexOf('  Future<void> _deleteDriver() async {');
  if (startIdx != -1 && endIdx != -1) {
    code = code.replaceRange(startIdx, endIdx, showRejectionMethod + '\n\n');
  } else {
    print('Failed to find _updateStatus boundaries');
  }

  // 3. Update 'Reject' button calls
  code = code.replaceAll("() => _updateStatus('rejected')", "_showRejectionDialog");

  File('lib/screens/user_management_tab.dart').writeAsStringSync(code);
  print('Admin rejection patched');
}
