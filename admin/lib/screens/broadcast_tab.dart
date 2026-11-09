import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class BroadcastTab extends StatefulWidget {
  const BroadcastTab({super.key});

  @override
  State<BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<BroadcastTab> {
  final _picker = ImagePicker();
  File? _imageFile;
  String _target = 'both';
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _publishBroadcast() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image.')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final newRef = FirebaseDatabase.instance.ref('broadcasts').push();
      final storageRef = FirebaseStorage.instance.ref().child('broadcasts/${newRef.key}.jpg');
      
      await storageRef.putFile(_imageFile!);
      final url = await storageRef.getDownloadURL();

      await newRef.set({
        'imageUrl': url,
        'target': _target,
        'isActive': true,
        'createdAt': ServerValue.timestamp,
      });

      if (mounted) {
        setState(() {
          _imageFile = null;
          _target = 'both';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast published successfully!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _toggleBroadcast(String id, bool currentStatus) async {
    await FirebaseDatabase.instance.ref('broadcasts/$id').update({
      'isActive': !currentStatus,
    });
  }

  Future<void> _deleteBroadcast(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Broadcast?'),
        content: const Text('Are you sure you want to delete this broadcast? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      
      final callable = FirebaseFunctions.instance.httpsCallable('deleteBroadcast');
      await callable.call({'broadcastId': id});
      
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast deleted successfully')));
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Send New Broadcast', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target Audience', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _target,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'both', child: Text('Drivers & Riders')),
                                DropdownMenuItem(value: 'drivers', child: Text('Only Drivers')),
                                DropdownMenuItem(value: 'riders', child: Text('Only Riders')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _target = val);
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isUploading ? null : _publishBroadcast,
                                icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                                label: Text(_isUploading ? 'Publishing...' : 'Publish Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Recent Broadcasts', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('broadcasts').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text('No broadcasts found.'));

                final broadcastsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                final List<Map<String, dynamic>> broadcasts = broadcastsMap.entries.map((e) {
                  return {
                    'id': e.key.toString(),
                    ...Map<String, dynamic>.from(e.value as Map),
                  };
                }).toList();
                
                // Sort by createdAt descending
                broadcasts.sort((a, b) {
                  final aTime = a['createdAt'] ?? 0;
                  final bTime = b['createdAt'] ?? 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: broadcasts.length,
                  itemBuilder: (context, index) {
                    final data = broadcasts[index];
                    final isActive = data['isActive'] ?? false;
                    final docId = data['id'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                        ),
                        title: Text('Target: ${data['target'].toString().toUpperCase()}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        subtitle: Text(isActive ? 'Currently Live' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              onChanged: (val) => _toggleBroadcast(docId, isActive),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteBroadcast(docId),
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
      ),
    );
  }
}
