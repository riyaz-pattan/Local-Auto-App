import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  String _searchQuery = '';
  Timer? _debounce;
  String _selectedFilter = 'All';
  int _currentLimit = 30;
  final List<String> _filters = ['All', 'Pending', 'Approved', 'Rejected', 'Hold'];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                onChanged: (val) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 600), () {
                    setState(() => _searchQuery = val.toLowerCase());
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedFilter = filter);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        
        // List of Drivers
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('drivers_index').onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading users', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final rtdbData = snapshot.data?.snapshot.value as Map<dynamic, dynamic>? ?? {};
              
              List<Map<String, dynamic>> allDrivers = [];
              rtdbData.forEach((key, value) {
                final driverData = Map<String, dynamic>.from(value as Map);
                driverData['id'] = key;
                allDrivers.add(driverData);
              });

              // Apply Tab Filter
              if (_selectedFilter != 'All') {
                allDrivers = allDrivers.where((d) => d['status'] == _selectedFilter.toLowerCase()).toList();
              }

              // Apply Search Filter
              if (_searchQuery.isNotEmpty) {
                allDrivers = allDrivers.where((d) => 
                  (d['name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
                  (d['phone'] as String? ?? '').contains(_searchQuery)
                ).toList();
              }

              // Sort by createdAt descending
              allDrivers.sort((a, b) {
                final aTime = a['createdAt'] as int? ?? 0;
                final bTime = b['createdAt'] as int? ?? 0;
                return bTime.compareTo(aTime);
              });

              final isEndReached = allDrivers.length <= _currentLimit;
              final displayDrivers = allDrivers.take(_currentLimit).toList();

              if (displayDrivers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No users found', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: displayDrivers.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == displayDrivers.length) {
                    if (isEndReached) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentLimit += 30;
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text('Load More Drivers', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  }
                  
                  final data = displayDrivers[index];
                  final driverId = data['id'] as String;
                  
                  final name = data['name'] as String? ?? 'Unknown Driver';
                  final phoneRaw = data['phone'] as String? ?? 'No phone';
                  final phone = phoneRaw.startsWith('+91') && !phoneRaw.contains(' ') 
                                ? phoneRaw.replaceFirst('+91', '+91 ') 
                                : phoneRaw;

                  final profileUrl = data['profilePhotoUrl'] as String?;
                  final status = data['status'] as String? ?? 'pending';

                  Color statusColor;
                  switch (status.toLowerCase()) {
                    case 'approved': statusColor = Colors.green; break;
                    case 'rejected': statusColor = Colors.red; break;
                    case 'hold': statusColor = Colors.orange; break;
                    default: statusColor = Colors.blue; break;
                  }

                  return InkWell(
                    onTap: () => _showDriverDetails(context, driverId, data),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                            child: profileUrl == null ? Icon(Icons.person, color: Theme.of(context).colorScheme.secondary) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(phone, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 14)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDriverDetails(BuildContext context, String driverId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverDetailSheet(
        driverId: driverId,
        initialData: data,
      ),
    );
  }
}

class DriverDetailSheet extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> initialData;

  const DriverDetailSheet({
    super.key,
    required this.driverId,
    required this.initialData,
  });

  @override
  State<DriverDetailSheet> createState() => _DriverDetailSheetState();
}

class _DriverDetailSheetState extends State<DriverDetailSheet> {
  bool _isLoading = false;
  final List<String> _rejectionReasons = [
    'Profile photo is blurry or unclear',
    'Aadhaar card details are not visible',
    'Driving license is expired or invalid',
    'Vehicle number does not match documents',
    'Fraudulent or duplicate profile',
    'Other (Specify below)'
  ];

  void _showRejectionDialog() {
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
                                ? '• ' + finalReasonsList.join('\n• ')
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDriver() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completely Wipe Driver?'),
        content: const Text('This will permanently delete the driver from Firestore, Authentication, and wipe all uploaded Storage photos. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Wipe Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteDriver');
      await callable.call({
        'driverId': widget.driverId,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with StreamBuilder to automatically update the sheet if status changes in background or if we want to reflect real-time data
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').doc(widget.driverId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
           // use initialData while loading
        }
        
        final data = snapshot.hasData && snapshot.data!.exists 
            ? snapshot.data!.data() as Map<String, dynamic> 
            : widget.initialData;

        final name = data['name'] as String? ?? 'Unknown Driver';
        final phoneRaw = data['phone'] as String? ?? 'No phone';
        final phone = phoneRaw.startsWith('+91') && !phoneRaw.contains(' ') 
                      ? phoneRaw.replaceFirst('+91', '+91 ') 
                      : phoneRaw;
        
        final vehicleNumber = data['vehicleNumber'] as String? ?? 'No vehicle';
        final profileUrl = data['profilePhotoUrl'] as String?;
        final aadhaarUrl = data['aadhaarUrl'] as String?;
        final licenseUrl = data['licenseUrl'] as String?;
        final status = data['status'] as String? ?? 'pending';

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Beautiful Header Profile
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 20),
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _openImageFullScreen(context, profileUrl),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 3),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.white,
                                backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                                child: profileUrl == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.phone, size: 16, color: Colors.blueGrey[400]),
                                    const SizedBox(width: 6),
                                    Text(phone, style: TextStyle(fontSize: 15, color: Colors.blueGrey[600], fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.directions_car, size: 16, color: Colors.blueGrey[400]),
                                    const SizedBox(width: 6),
                                    Text(vehicleNumber, style: TextStyle(fontSize: 15, color: Colors.blueGrey[600], fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              
              // Documents Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KYC Documents', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDocPreview(context, 'Aadhaar Card', aadhaarUrl)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDocPreview(context, 'Driving License', licenseUrl)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Buttons
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5)),
                  ],
                ),
                child: SafeArea(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildActionButtons(status),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildActionButtons(String status) {
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: _buildBtn('Reject', Colors.red, _showRejectionDialog, isOutlined: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildBtn('Hold', Colors.orange, () => _updateStatus('hold'), isOutlined: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildBtn('Approve', Colors.green, () => _updateStatus('approved'), isOutlined: false),
          ),
        ],
      );
    } else if (status == 'approved') {
      return Row(
        children: [
          Expanded(
            child: _buildBtn('Hold Account', Colors.orange, () => _updateStatus('hold'), isOutlined: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildBtn('Wipe Data', Colors.red, _deleteDriver, isOutlined: false),
          ),
        ],
      );
    } else if (status == 'hold') {
      return Row(
        children: [
          Expanded(
            child: _buildBtn('Reject', Colors.red, _showRejectionDialog, isOutlined: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildBtn('Wipe Data', Colors.red, _deleteDriver, isOutlined: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildBtn('Approve', Colors.green, () => _updateStatus('approved'), isOutlined: false),
          ),
        ],
      );
    } else if (status == 'rejected') {
      return Row(
        children: [
          Expanded(
            child: _buildBtn('Wipe Data', Colors.red, _deleteDriver, isOutlined: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildBtn('Approve', Colors.green, () => _updateStatus('approved'), isOutlined: false),
          ),
        ],
      );
    }
    
    // Fallback
    return const SizedBox();
  }

  Widget _buildBtn(String label, Color color, VoidCallback onPressed, {required bool isOutlined}) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    } else {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }
  }

  Widget _buildDocPreview(BuildContext context, String label, String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hide_image, color: Colors.grey[300], size: 40),
            const SizedBox(height: 12),
            Text('Missing', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openImageFullScreen(context, url),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
          ],
          image: DecorationImage(
            image: NetworkImage(url),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.all(16),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _openImageFullScreen(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
