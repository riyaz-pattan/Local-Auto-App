import 'dart:io';

void main() {
  String code = File('lib/screens/user_management_tab.dart').readAsStringSync();
  
  String oldMethod = '''  void _showRejectionDialog() {
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
  }''';

  String newMethod = '''  void _showRejectionDialog() {
    final List<String> selectedReasons = [];
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reject Driver', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Text('Select reasons for rejection (multiple allowed):'),
                      const SizedBox(height: 8),
                      ..._rejectionReasons.map((reason) {
                        return CheckboxListTile(
                          title: Text(reason),
                          value: selectedReasons.contains(reason),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          onChanged: (bool? checked) {
                            setModalState(() {
                              if (checked == true) {
                                selectedReasons.add(reason);
                              } else {
                                selectedReasons.remove(reason);
                              }
                            });
                          },
                        );
                      }),
                      if (selectedReasons.contains('Other (Specify below)')) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: manualReasonController,
                          decoration: InputDecoration(
                            labelText: 'Enter detailed reason',
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
                            List<String> finalReasonsList = [];
                            for (var r in selectedReasons) {
                              if (r != 'Other (Specify below)') {
                                finalReasonsList.add(r);
                              }
                            }
                            
                            if (selectedReasons.contains('Other (Specify below)') && manualReasonController.text.trim().isNotEmpty) {
                              finalReasonsList.add(manualReasonController.text.trim());
                            }

                            if (finalReasonsList.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select or enter at least one reason')));
                              return;
                            }
                            
                            final formattedReason = finalReasonsList.length > 1 
                                ? '• ' + finalReasonsList.join('\\n• ')
                                : finalReasonsList.first;
                            
                            Navigator.pop(ctx);
                            _updateStatus('rejected', reason: formattedReason);
                          },
                          child: const Text('Confirm Rejection'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }''';

  if (code.contains(oldMethod)) {
    code = code.replaceFirst(oldMethod, newMethod);
    File('lib/screens/user_management_tab.dart').writeAsStringSync(code);
    print('Multi-reason patch applied');
  } else {
    print('Failed to find old method');
  }
}
